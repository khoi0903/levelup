package vn.levelup.engagement.service;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.util.Date;
import java.util.Locale;
import org.springframework.context.ApplicationEventPublisher;
import vn.levelup.engagement.dto.ReferralCompleted;
import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.engagement.dto.ReferralDtos;
import vn.levelup.identity.model.User;
import vn.levelup.identity.service.ProductConfigService;
import vn.levelup.identity.service.PlanGrantService;

@Service
public class ReferralService {
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final String ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    private final MongoTemplate mongo;
    private final ProductConfigService configs;
    private final PlanGrantService grants;
    private final ApplicationEventPublisher events;
    private final Clock clock;
    private final String linkBase;
    public ReferralService(MongoTemplate mongo, ProductConfigService configs, PlanGrantService grants,
            ApplicationEventPublisher events, Clock clock,
            @Value("${levelup.referral.link-base:}") String linkBase) {
        this.mongo = mongo; this.configs = configs; this.grants = grants;
        this.events = events; this.clock = clock; this.linkBase = linkBase;
    }
    private void enabled() {
        if (!configs.get().referralEnabled()) fail("REFERRAL_DISABLED");
    }
    private static void fail(String code) { throw new ResponseStatusException(HttpStatus.BAD_REQUEST, code); }
    @Transactional
    public ReferralDtos.View me(User user, String origin) {
        enabled();
        ObjectId id = new ObjectId(user.id());
        Document latest = mongo.findById(id, Document.class, "users");
        String code = latest.getString("referralCode");
        if (code == null) {
            do {
                StringBuilder b = new StringBuilder();
                for (int i = 0; i < 8; i++) b.append(ALPHABET.charAt(RANDOM.nextInt(ALPHABET.length())));
                code = b.toString();
            } while (mongo.exists(Query.query(Criteria.where("referralCode").is(code)), "users"));
            mongo.updateFirst(Query.query(Criteria.where("_id").is(id)), Update.update("referralCode", code), "users");
        }
        long count = successfulCount(id);
        var milestones = configs.get().referralMilestones();
        var rewards = mongo.find(Query.query(Criteria.where("referrerId").is(id)), Document.class, "referral_rewards")
            .stream().map(d -> new ReferralDtos.Reward(d.getInteger("friends"), d.getInteger("days"), d.getDate("at").toInstant())).toList();
        return new ReferralDtos.View(code, (linkBase.isBlank() ? origin + "/referral.html" : linkBase) + "?code=" + code, count,
            milestones.stream().filter(m -> m.friends() > count).findFirst().orElse(null), rewards, milestones);
    }
    public boolean canRedeem(User user) {
        return configs.get().referralEnabled() && user.createdAt() != null
            && !clock.instant().isAfter(user.createdAt().plus(Duration.ofDays(7)))
            && !hasRedeemed(new ObjectId(user.id()));
    }
    @Transactional
    public void redeem(User user, String rawCode) {
        enabled();
        ObjectId inviteeId = new ObjectId(user.id());
        if (hasRedeemed(inviteeId)) fail("ALREADY_REDEEMED");
        if (user.createdAt() == null || clock.instant().isAfter(user.createdAt().plus(Duration.ofDays(7)))) fail("TOO_LATE");
        String code = rawCode.trim().toUpperCase(Locale.ROOT);
        Document referrer = mongo.findOne(Query.query(Criteria.where("referralCode").is(code)), Document.class, "users");
        if (referrer == null) fail("INVALID_CODE");
        ObjectId referrerId = referrer.getObjectId("_id");
        if (referrerId.equals(inviteeId)) fail("OWN_CODE");
        mongo.insert(new Document("referrerId", referrerId).append("inviteeId", inviteeId)
            .append("status", "pending").append("createdAt", Date.from(clock.instant())), "referrals");
        mongo.updateFirst(Query.query(Criteria.where("_id").is(inviteeId)),
            Update.update("referralRedeemedAt", Date.from(clock.instant())), "users");
        grants.addDays(inviteeId, configs.get().referralInviteeDays(), "referral");
    }
    private boolean hasRedeemed(ObjectId id) {
        // Keep the one-time claim even if a referrer later deletes their account and referral records.
        return mongo.exists(Query.query(Criteria.where("_id").is(id).and("referralRedeemedAt").exists(true)), "users")
            || mongo.exists(Query.query(Criteria.where("inviteeId").is(id)), "referrals");
    }
    private long successfulCount(ObjectId id) {
        return mongo.count(Query.query(Criteria.where("referrerId").is(id).and("status").is("completed")), "referrals");
    }
    /** Joins WorkoutService's transaction; log, completion, reward ledger and plan commit together. */
    @Transactional
    public void completeFirstWorkout(ObjectId inviteeId) {
        Document referral = mongo.findAndModify(Query.query(Criteria.where("inviteeId").is(inviteeId)
            .and("status").is("pending")), Update.update("status", "completed")
                .set("completedAt", Date.from(clock.instant())), Document.class, "referrals");
        if (referral == null) return;
        ObjectId referrerId = referral.getObjectId("referrerId");
        // Touch the referrer to serialize concurrent invitees, even when neither reaches a milestone yet.
        var updated = mongo.updateFirst(Query.query(Criteria.where("_id").is(referrerId)),
            new Update().inc("referralSuccessfulCount", 1), "users");
        if (updated.getMatchedCount() == 0) return;
        long count = successfulCount(referrerId);
        for (var milestone : configs.get().referralMilestones()) {
            Query key = Query.query(Criteria.where("referrerId").is(referrerId).and("friends").is(milestone.friends()));
            if (count >= milestone.friends() && !mongo.exists(key, "referral_rewards")) {
                mongo.insert(new Document("referrerId", referrerId).append("friends", milestone.friends())
                    .append("days", milestone.days()).append("at", Date.from(clock.instant())), "referral_rewards");
                grants.addDays(referrerId, milestone.days(), "referral");
            }
        }
        events.publishEvent(new ReferralCompleted(referral.getObjectId("_id").toHexString(), referrerId.toHexString(), count));
    }
}
