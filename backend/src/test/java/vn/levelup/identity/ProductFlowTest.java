package vn.levelup.identity;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.when;
import vn.levelup.nutrition.service.MealRecognitionService;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;
import org.bson.Document;
import org.bson.types.ObjectId;
import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.query.*;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import com.jayway.jsonpath.DocumentContext;
import vn.levelup.FlowTestBase;
import vn.levelup.coach.ai.AiClient;
import vn.levelup.identity.service.PlanAccess;
import vn.levelup.identity.service.ProductConfigService;

@SpringBootTest(properties = {"REVENUECAT_WEBHOOK_SECRET=Bearer test-billing-secret", "levelup.demo.enabled=false", "levelup.demo.uids=product-admin"})
@ActiveProfiles("dev")
class ProductFlowTest extends FlowTestBase {
    @MockitoBean AiClient ai;
    @Autowired PlanAccess plans;
    @Autowired vn.levelup.identity.service.RevenueCatService billing;
    @Autowired ProductConfigService configs;
    private Document originalConfig;
    private final List<ObjectId> addedUsers = new ArrayList<>();
    private static final String ADMIN = "Bearer dev-product-admin";

    @BeforeEach
    void defaults() {
        originalConfig = mongo.findById("product", Document.class, "app_config");
        mongo.remove(Query.query(Criteria.where("_id").is("product")), "app_config");
        configs.invalidate();
    }
    @AfterEach
    void restore() {
        Document own = mongo.findOne(Query.query(Criteria.where("authUid").is(uid)), Document.class, "users");
        if (own != null) addedUsers.add(own.getObjectId("_id"));
        for (ObjectId id : addedUsers) {
            for (String c : List.of("billing_events", "workout_logs", "training_plans", "daily_stats", "weekly_streaks", "personal_records", "coach_messages", "notifications", "food_recognitions"))
                mongo.remove(Query.query(Criteria.where("userId").is(id)), c);
            mongo.remove(Query.query(new Criteria().orOperator(Criteria.where("referrerId").is(id), Criteria.where("inviteeId").is(id))), "referrals");
            mongo.remove(Query.query(Criteria.where("referrerId").is(id)), "referral_rewards");
            mongo.remove(Query.query(Criteria.where("_id").is(id)), "users");
        }
        mongo.remove(Query.query(Criteria.where("uid").is("product-admin")), "admin_audit");
        mongo.remove(Query.query(Criteria.where("_id").is("product")), "app_config");
        if (originalConfig != null) mongo.insert(originalConfig, "app_config");
        configs.invalidate();
    }
    private DocumentContext me() throws Exception { return call(get("/me").header("Authorization", token), 200); }
    private Document config() throws Exception {
        return Document.parse(call(get("/admin/config").header("Authorization", ADMIN), 200).jsonString());
    }
    private void flags(boolean pro, boolean referral) throws Exception {
        Document c = config(); c.put("proEnabled", pro); c.put("referralEnabled", referral);
        call(put("/admin/config").header("Authorization", ADMIN).contentType(MediaType.APPLICATION_JSON).content(c.toJson()), 200);
    }
    private String webhook(String type, String id, Long expires, long timestamp) {
        return new Document("event", new Document("id", id).append("type", type).append("app_user_id", uid)
            .append("expiration_at_ms", expires).append("event_timestamp_ms", timestamp)).toJson();
    }
    private void event(String type, String id, Long expires, long timestamp) throws Exception {
        call(post("/billing/revenuecat/webhook").header("Authorization", "Bearer test-billing-secret")
            .contentType(MediaType.APPLICATION_JSON).content(webhook(type, id, expires, timestamp)), 204);
    }
    private Document user(ObjectId id) { return mongo.findById(id, Document.class, "users"); }
    private ObjectId addUser(String code) {
        ObjectId id = new ObjectId(); addedUsers.add(id);
        Document d = new Document("_id", id).append("authUid", "it-product-" + id).append("displayName", "Bạn")
            .append("timezone", "Asia/Ho_Chi_Minh").append("createdAt", new Date());
        if (code != null) d.append("referralCode", code);
        mongo.insert(d, "users"); return id;
    }
    private DocumentContext redeem(String code, int status) throws Exception {
        return call(post("/referrals/redeem").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content(new Document("code", code).toJson()), status);
    }
    private String workout(String exercise, String client, int seconds) {
        Instant end = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        return new Document("clientId", client).append("startedAt", end.minusSeconds(seconds).toString())
            .append("endedAt", end.toString()).append("variant", "normal")
            .append("sets", List.of(new Document("exerciseId", exercise).append("setIndex", 1).append("reps", 8))).toJson();
    }
    private void saveWorkout(String body) throws Exception {
        call(post("/workouts").header("Authorization", token).contentType(MediaType.APPLICATION_JSON).content(body), 200);
    }

    @Test void defaultsAndDisabledLimitsStayCompatible() throws Exception {
        onboard();
        assertFalse(me().read("$.subscription.enabled", Boolean.class));
        assertEquals(30, me().read("$.subscription.limits.coachPerDay", Integer.class));
        assertEquals(10, me().read("$.subscription.limits.photosPerDay", Integer.class));
        assertFalse(me().read("$.isAdmin", Boolean.class));
        for (int i = 0; i < 30; i++) call(post("/coach/messages").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content("{\"text\":\"Xin chào\"}"), 200);
        assertEquals("COACH_LIMIT", call(post("/coach/messages").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content("{\"text\":\"Xin chào\"}"), 429).read("$.code"));
    }
    @Test void freeEleventhMessageBlockedAndConfigTakesEffectImmediately() throws Exception {
        onboard(); flags(true, false);
        for (int i = 0; i < 10; i++) call(post("/coach/messages").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content("{\"text\":\"Xin chào\"}"), 200);
        assertEquals("COACH_LIMIT", call(post("/coach/messages").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content("{\"text\":\"Xin chào\"}"), 429).read("$.code"));
        Document c = config(); c.put("coachFreePerDay", 11);
        call(put("/admin/config").header("Authorization", ADMIN).contentType(MediaType.APPLICATION_JSON).content(c.toJson()), 200);
        call(post("/coach/messages").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"text\":\"Xin chào\"}"), 200);
        assertEquals(11, me().read("$.subscription.limits.coachPerDay", Integer.class));
    }
    @Test void photosRespectFreeProAndDisabledQuotasIncludingZero() throws Exception {
        onboard(); flags(true, false);
        when(ai.available()).thenReturn(true);
        when(ai.completeWithImage(anyString(), anyString(), any(), anyString(), anyInt())).thenReturn("{\"dishes\":[]}");
        for (int i = 0; i < 3; i++) photo(i, 200);
        assertEquals("PHOTO_LIMIT_REACHED", photo(3, 429).read("$.code"));
        event("INITIAL_PURCHASE", UUID.randomUUID().toString(), Instant.now().plus(10, ChronoUnit.DAYS).toEpochMilli(), 1);
        photo(3, 200);
        flags(false, false);
        mongo.updateFirst(Query.query(Criteria.where("userId").is(userId())), Update.update("usage.photoScans", 10), "daily_stats");
        photo(4, 429);
        flags(true, false);
        Document c = config(); c.put("photosProPerDay", 0);
        call(put("/admin/config").header("Authorization", ADMIN).contentType(MediaType.APPLICATION_JSON).content(c.toJson()), 200);
        photo(5, 429);
    }
    private DocumentContext photo(int seed, int expected) throws Exception {
        byte[] bytes = ("test-image-" + seed).getBytes(java.nio.charset.StandardCharsets.UTF_8);
        return call(post("/meals/recognize").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content(new Document("imageBase64", Base64.getEncoder().encodeToString(bytes)).append("mediaType", "image/jpeg")
                .append("sha256", MealRecognitionService.sha256Hex(bytes)).toJson()), expected);
    }
    @Test void webhookWrongSecretUnauthorizedEvenWithoutBody() throws Exception {
        call(post("/billing/revenuecat/webhook").header("Authorization", "wrong").contentType(MediaType.APPLICATION_JSON)
            .content(webhook("INITIAL_PURCHASE", "wrong", 123L, 1)), 401);
        call(post("/billing/revenuecat/webhook"), 401);
    }
    @Test void purchaseRenewalCancellationExpirationAndDuplicate() throws Exception {
        onboard(); flags(true, false);
        long expiry = Instant.now().plus(20, ChronoUnit.DAYS).toEpochMilli();
        String eventId = UUID.randomUUID().toString();
        event("INITIAL_PURCHASE", eventId, expiry, 1);
        assertEquals("pro", me().read("$.subscription.tier"));
        assertEquals(100, me().read("$.subscription.limits.coachPerDay", Integer.class));
        assertEquals(30, me().read("$.subscription.limits.photosPerDay", Integer.class));
        event("INITIAL_PURCHASE", eventId, expiry, 1);
        assertEquals(1, mongo.count(Query.query(Criteria.where("eventId").is(eventId)), "billing_events"));
        event("CANCELLATION", UUID.randomUUID().toString(), null, 2);
        assertEquals("pro", me().read("$.subscription.tier"));
        assertEquals(expiry, user(userId()).get("plan", Document.class).getDate("expiresAt").getTime());
        event("EXPIRATION", UUID.randomUUID().toString(), expiry, 3);
        assertEquals("free", me().read("$.subscription.tier"));
        event("RENEWAL", UUID.randomUUID().toString(), expiry, 4);
        assertEquals("pro", me().read("$.subscription.tier"));
        event("EXPIRATION", UUID.randomUUID().toString(), expiry, 2);
        assertEquals("pro", me().read("$.subscription.tier"), "older delivery cannot remove renewal");
    }
    @Test void concurrentWebhookDeliveryCommitsExactlyOnce() throws Exception {
        onboard();
        String id = UUID.randomUUID().toString();
        var event = new vn.levelup.identity.dto.BillingWebhook.Event(id, "INITIAL_PURCHASE", uid,
            Instant.now().plus(10, ChronoUnit.DAYS).toEpochMilli(), 1L);
        try (var workers = java.util.concurrent.Executors.newFixedThreadPool(2)) {
            var start = new java.util.concurrent.CountDownLatch(1);
            var first = workers.submit(() -> { start.await(); billing.handle(event); return true; });
            var second = workers.submit(() -> { start.await(); billing.handle(event); return true; });
            start.countDown();
            assertTrue(first.get(10, java.util.concurrent.TimeUnit.SECONDS));
            assertTrue(second.get(10, java.util.concurrent.TimeUnit.SECONDS));
        }
        assertEquals(1, mongo.count(Query.query(Criteria.where("eventId").is(id)), "billing_events"));
        assertEquals("pro", me().read("$.subscription.tier"));
    }
    @Test void expiredPlanUsesFreeLimitsFromServerTime() throws Exception {
        onboard(); flags(true, false);
        event("INITIAL_PURCHASE", UUID.randomUUID().toString(), Instant.now().minusSeconds(1).toEpochMilli(), 1);
        assertEquals("free", me().read("$.subscription.tier"));
        assertEquals(10, me().read("$.subscription.limits.coachPerDay", Integer.class));
        flags(false, false);
        assertEquals(30, me().read("$.subscription.limits.coachPerDay", Integer.class));
    }
    @Test void normalUserAlways404AdminAndAdminIndependentOfDemoMode() throws Exception {
        onboard();
        call(get("/admin/config").header("Authorization", token), 404);
        call(put("/admin/config").header("Authorization", token).contentType(MediaType.APPLICATION_JSON).content("{}"), 404);
        call(post("/admin/grant-pro").header("Authorization", token).contentType(MediaType.APPLICATION_JSON).content("{}"), 404);
        String previous = token; token = ADMIN; onboard();
        assertTrue(me().read("$.isAdmin", Boolean.class));
        assertFalse(me().read("$.demoEnabled", Boolean.class));
        addedUsers.add(userId()); token = previous;
        call(post("/demo/seed").header("Authorization", ADMIN), 404);
    }
    @Test void adminValidationAuditAndOptimisticVersion() throws Exception {
        Document c = config(); c.put("coachFreePerDay", -1);
        call(put("/admin/config").header("Authorization", ADMIN).contentType(MediaType.APPLICATION_JSON).content(c.toJson()), 400);
        c = config(); c.put("monthlyPriceVnd", 0);
        call(put("/admin/config").header("Authorization", ADMIN).contentType(MediaType.APPLICATION_JSON).content(c.toJson()), 400);
        c = config(); c.put("referralMilestones", List.of(new Document("friends", 3).append("days", 30), new Document("friends", 1).append("days", 7)));
        call(put("/admin/config").header("Authorization", ADMIN).contentType(MediaType.APPLICATION_JSON).content(c.toJson()), 400);
        Document initial = config(); flags(true, true);
        assertEquals(1, mongo.count(Query.query(Criteria.where("uid").is("product-admin")), "admin_audit"));
        assertTrue(configs.get().proEnabled());
        call(put("/admin/config").header("Authorization", ADMIN).contentType(MediaType.APPLICATION_JSON).content(initial.toJson()), 409);
    }
    @Test void revenueCatExpirationKeepsGiftedDays() throws Exception {
        onboard(); flags(true, false);
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId())), Update.update("email", "gift@example.com"), "users");
        call(post("/admin/grant-pro").header("Authorization", ADMIN).contentType(MediaType.APPLICATION_JSON)
            .content("{\"email\":\"gift@example.com\",\"days\":30}"), 204);
        event("INITIAL_PURCHASE", UUID.randomUUID().toString(), Instant.now().plus(3, ChronoUnit.DAYS).toEpochMilli(), 1);
        event("EXPIRATION", UUID.randomUUID().toString(), Instant.now().toEpochMilli(), 2);
        assertEquals("pro", me().read("$.subscription.tier"), "hết hạn trả tiền không xoá 30 ngày tặng");
        Document plan = user(userId()).get("plan", Document.class);
        assertEquals("manual", plan.getString("source"));
        assertTrue(plan.getDate("expiresAt").toInstant().isAfter(Instant.now().plus(29, ChronoUnit.DAYS)));
    }
    @Test void adminGrantManualExtendsExistingPlan() throws Exception {
        onboard();
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId())), Update.update("email", "target@example.com"), "users");
        for (int i = 0; i < 2; i++) call(post("/admin/grant-pro").header("Authorization", ADMIN).contentType(MediaType.APPLICATION_JSON)
            .content("{\"email\":\"TARGET@example.com\",\"days\":7}"), 204);
        Document plan = user(userId()).get("plan", Document.class);
        assertEquals("manual", plan.getString("source"));
        assertTrue(plan.getDate("expiresAt").toInstant().isAfter(Instant.now().plus(13, ChronoUnit.DAYS)));
    }
    @Test void referralErrorsAndInviteeGrant() throws Exception {
        onboard();
        assertEquals("REFERRAL_DISABLED", redeem("INVALID", 400).read("$.code"));
        flags(true, true);
        String own = call(get("/referrals/me").header("Authorization", token), 200).read("$.code");
        assertTrue(own.matches("[A-Z2-9]{8}"));
        assertEquals(own, call(get("/referrals/me").header("Authorization", token), 200).read("$.code"));
        assertEquals("OWN_CODE", redeem(own, 400).read("$.code"));
        assertEquals("INVALID_CODE", redeem("INVALID", 400).read("$.code"));
        addUser("FRIEND77");
        redeem("friend77", 204);
        assertEquals("pro", me().read("$.subscription.tier"));
        assertEquals("referral", user(userId()).get("plan", Document.class).getString("source"));
        assertFalse(me().read("$.referralRedeemEligible", Boolean.class));
        assertEquals("ALREADY_REDEEMED", redeem("FRIEND77", 400).read("$.code"));
        mongo.remove(Query.query(Criteria.where("inviteeId").is(userId())), "referrals");
        assertEquals("ALREADY_REDEEMED", redeem("FRIEND77", 400).read("$.code"), "deleting referrer history must not allow a second claim");
    }
    @Test void referralOlderThanSevenDaysRejected() throws Exception {
        onboard(); flags(true, true); addUser("FRIEND88");
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId())), Update.update("createdAt", Date.from(Instant.now().minus(8, ChronoUnit.DAYS))), "users");
        assertEquals("TOO_LATE", redeem("FRIEND88", 400).read("$.code"));
    }
    @Test void firstQualifyingWorkoutCompletesOnceAndMilestonesAccumulate() throws Exception {
        var onboarding = onboard(); flags(true, true);
        String exercise = onboarding.read("$.plan.sessions[0].items[0].exerciseId");
        ObjectId referrer = addUser("FRIEND99");
        // Two completed friends: the next completion crosses both unclaimed 1- and 3-friend milestones.
        for (int i = 0; i < 2; i++) mongo.insert(new Document("referrerId", referrer).append("inviteeId", addUser(null)).append("status", "completed"), "referrals");
        redeem("FRIEND99", 204);
        saveWorkout(workout(exercise, "short-first", 299));
        assertEquals("pending", mongo.findOne(Query.query(Criteria.where("inviteeId").is(userId())), Document.class, "referrals").getString("status"));
        String body = workout(exercise, "qualified-first", 300);
        saveWorkout(body); saveWorkout(body); saveWorkout(workout(exercise, "qualified-second", 600));
        assertEquals(3, mongo.count(Query.query(Criteria.where("referrerId").is(referrer).and("status").is("completed")), "referrals"));
        assertEquals(2, mongo.count(Query.query(Criteria.where("referrerId").is(referrer)), "referral_rewards"));
        Document p = user(referrer).get("plan", Document.class);
        assertEquals("referral", p.getString("source"));
        assertTrue(p.getDate("expiresAt").toInstant().isAfter(Instant.now().plus(36, ChronoUnit.DAYS)));
        assertTrue(p.getDate("expiresAt").toInstant().isBefore(Instant.now().plus(38, ChronoUnit.DAYS)));
        assertEquals(1, mongo.count(Query.query(Criteria.where("userId").is(referrer).and("type").is("referral_completed")), "notifications"));
    }
}
