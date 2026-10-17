package vn.levelup.identity.service;

import java.time.Clock;
import java.time.Instant;
import java.util.Date;
import java.util.Set;
import org.bson.Document;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import com.mongodb.MongoException;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.identity.dto.BillingWebhook;

@Service
public class RevenueCatService {
    private static final Logger log = LoggerFactory.getLogger(RevenueCatService.class);
    private static final Set<String> PURCHASE = Set.of("INITIAL_PURCHASE", "RENEWAL", "PRODUCT_CHANGE", "UNCANCELLATION");
    private final MongoTemplate mongo;
    private final Clock clock;
    private final TransactionTemplate transactions;
    public RevenueCatService(MongoTemplate mongo, Clock clock, PlatformTransactionManager manager) {
        this.mongo = mongo; this.clock = clock; this.transactions = new TransactionTemplate(manager);
    }

    public void handle(BillingWebhook.Event event) {
        for (int attempt = 0; ; attempt++) {
            try {
                transactions.executeWithoutResult(status -> apply(event));
                return;
            } catch (org.springframework.dao.DuplicateKeyException duplicate) {
                // The competing transaction committed this same event; all of ours was rolled back.
                if (mongo.exists(Query.query(Criteria.where("eventId").is(event.id())), "billing_events")) return;
                throw duplicate;
            } catch (RuntimeException failure) {
                if (attempt >= 3 || !transientTransaction(failure)) throw failure;
            }
        }
    }
    private static boolean transientTransaction(Throwable error) {
        for (Throwable cause = error; cause != null; cause = cause.getCause())
            if (cause instanceof MongoException mongoError && (mongoError.hasErrorLabel("TransientTransactionError")
                    || mongoError.hasErrorLabel("UnknownTransactionCommitResult"))) return true;
        return false;
    }
    private void apply(BillingWebhook.Event event) {
        if (mongo.exists(Query.query(Criteria.where("eventId").is(event.id())), "billing_events")) return;
        if (PURCHASE.contains(event.type()) && (event.expirationAtMs() == null || event.expirationAtMs() < 0))
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_EXPIRATION");
        Document user = mongo.findOne(Query.query(Criteria.where("authUid").is(event.appUserId())), Document.class, "users");
        if (user == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND");
        mongo.insert(new Document("eventId", event.id()).append("type", event.type())
            .append("userId", user.getObjectId("_id")).append("at", Date.from(clock.instant())), "billing_events");
        Document plan = user.get("plan", new Document());
        long timestamp = event.eventTimestampMs() == null ? clock.millis() : event.eventTimestampMs();
        // Late delivery must not undo a newer renewal/expiration.
        Long previous = user.getLong("billingEventTimestampMs");
        if (previous != null && timestamp < previous) return;
        // Chỉ đổi hạn trả tiền; ngày Pro được tặng (giới thiệu, admin) giữ nguyên
        if (PURCHASE.contains(event.type())) {
            plan = PlanGrantService.planDocument(PlanGrantService.giftExpiry(plan), PlanGrantService.giftSource(plan),
                Instant.ofEpochMilli(event.expirationAtMs()), clock.instant());
        } else if ("EXPIRATION".equals(event.type())) {
            plan = PlanGrantService.planDocument(PlanGrantService.giftExpiry(plan), PlanGrantService.giftSource(plan),
                clock.instant(), clock.instant());
        } else if (!"CANCELLATION".equals(event.type())) {
            log.info("[billing] ignored event={} type={}", event.id(), event.type());
            return;
        }
        mongo.updateFirst(Query.query(Criteria.where("_id").is(user.getObjectId("_id"))),
            Update.update("plan", plan).set("billingEventTimestampMs", timestamp), "users");
        log.info("[billing] processed event={} type={}", event.id(), event.type());
    }
}
