package vn.levelup.identity.service;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.identity.rules.PlanRules;

@Service
public class PlanGrantService {
    private final MongoTemplate mongo;
    private final Clock clock;
    public PlanGrantService(MongoTemplate mongo, Clock clock) { this.mongo = mongo; this.clock = clock; }

    // Called inside the caller's transaction: concurrent grants conflict instead of losing days.
    // Ngày tặng cộng vào hạn tặng (giftExpiresAt), không đụng tới hạn trả tiền của RevenueCat.
    public void addDays(ObjectId userId, int days, String source) {
        Document user = mongo.findById(userId, Document.class, "users");
        if (user == null) throw new ResponseStatusException(HttpStatus.NOT_FOUND, "USER_NOT_FOUND");
        Document plan = user.get("plan", Document.class);
        Instant now = clock.instant();
        Instant gift = giftExpiry(plan);
        Instant base = gift != null && gift.isAfter(now) ? gift : now;
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)), Update.update("plan",
            planDocument(base.plus(days, ChronoUnit.DAYS), source, paidExpiry(plan), now)), "users");
    }

    /** users.plan: tier/source/expiresAt là hạn thực tế (PlanAccess đọc), kèm hai hạn gốc để tính lại. */
    static Document planDocument(Instant gift, String giftSource, Instant paid, Instant now) {
        PlanRules.Effective e = PlanRules.effective(gift, giftSource, paid, now);
        Document d = new Document("tier", e.tier()).append("source", e.source())
            .append("expiresAt", Date.from(e.expiresAt() == null ? now : e.expiresAt()))
            .append("updatedAt", Date.from(now));
        if (gift != null) d.append("giftExpiresAt", Date.from(gift)).append("giftSource", giftSource);
        if (paid != null) d.append("paidExpiresAt", Date.from(paid));
        return d;
    }

    static Instant giftExpiry(Document plan) {
        if (plan == null) return null;
        return PlanRules.giftExpiry(instant(plan, "giftExpiresAt"), plan.getString("source"), instant(plan, "expiresAt"));
    }

    static String giftSource(Document plan) {
        if (plan == null) return null;
        String s = plan.getString("giftSource");
        return s != null ? s : PlanRules.PAID_SOURCE.equals(plan.getString("source")) ? null : plan.getString("source");
    }

    static Instant paidExpiry(Document plan) {
        if (plan == null) return null;
        return PlanRules.paidExpiry(instant(plan, "paidExpiresAt"), plan.getString("source"), instant(plan, "expiresAt"));
    }

    private static Instant instant(Document d, String key) {
        return d.get(key) instanceof Date date ? date.toInstant() : null;
    }
}
