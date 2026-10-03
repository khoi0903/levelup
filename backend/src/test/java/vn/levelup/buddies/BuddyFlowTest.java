package vn.levelup.buddies;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import jakarta.servlet.Filter;

import vn.levelup.common.LocalDates;
import org.bson.Document;
import org.bson.types.ObjectId;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.RequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import com.jayway.jsonpath.DocumentContext;
import com.jayway.jsonpath.JsonPath;

/**
 * Chạy trên MongoDB dev (localhost:27018, cần docker compose up, init.js và seed bài tập).
 * Hai người dùng thử: Minh mời, Lan nhập mã, Lan xem và nhắc Minh, Minh tập xong, Lan rời cặp.
 * Dọn dữ liệu của cả hai sau mỗi test.
 */
@SpringBootTest
@ActiveProfiles("dev")
class BuddyFlowTest {

    @Autowired WebApplicationContext context;
    @Autowired MongoTemplate mongo;

    MockMvc mvc;
    String minh;
    String lan;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(context)
            .addFilters(context.getBean("springSecurityFilterChain", Filter.class)).build();
        minh = "Bearer dev-it-" + UUID.randomUUID();
        lan = "Bearer dev-it-" + UUID.randomUUID();
    }

    @AfterEach
    void cleanUp() {
        for (String token : List.of(minh, lan)) {
            ObjectId userId = userId(token);
            if (userId == null) {
                continue;
            }
            Query mine = Query.query(Criteria.where("userId").is(userId));
            for (String c : new String[] {"workout_logs", "training_plans", "weekly_streaks", "personal_records",
                                          "daily_stats"}) {
                mongo.remove(mine, c);
            }
            mongo.remove(Query.query(Criteria.where("inviterId").is(userId)), "buddy_invites");
            mongo.remove(Query.query(Criteria.where("members").is(userId)), "buddy_pairs");
            mongo.remove(Query.query(new Criteria().orOperator(Criteria.where("fromUser").is(userId),
                Criteria.where("toUser").is(userId))), "buddy_actions");
            mongo.remove(Query.query(Criteria.where("_id").is(userId)), "users");
        }
    }

    private ObjectId userId(String token) {
        Document user = mongo.findOne(Query.query(Criteria.where("authUid").is(token.substring("Bearer dev-".length()))),
            Document.class, "users");
        return user == null ? null : user.getObjectId("_id");
    }

    private DocumentContext call(RequestBuilder req, int expected) throws Exception {
        String body = mvc.perform(req).andExpect(status().is(expected)).andReturn().getResponse()
            .getContentAsString(StandardCharsets.UTF_8);
        return JsonPath.parse(body.isEmpty() ? "{}" : body);
    }

    private DocumentContext postJson(String url, String token, String body, int expected) throws Exception {
        return call(post(url).header("Authorization", token).contentType(MediaType.APPLICATION_JSON).content(body),
            expected);
    }

    private String onboard(String token, String name) throws Exception {
        String body = """
            {"displayName":"%s","goal":"lose_fat","gender":"male","birthYear":1995,"heightCm":170,
             "weightKg":70,"experience":"beginner","location":"home","equipment":[],"injuries":[],
             "availability":[{"weekday":1,"slot":"evening"},{"weekday":2,"slot":"evening"},
               {"weekday":3,"slot":"evening"},{"weekday":4,"slot":"evening"},{"weekday":5,"slot":"evening"},
               {"weekday":6,"slot":"evening"},{"weekday":7,"slot":"evening"}],
             "sessionMinutes":15,"coachStyle":"supportive","timezone":"Asia/Ho_Chi_Minh"}""".formatted(name);
        return postJson("/onboarding", token, body, 200).read("$.plan.sessions[0].items[0].exerciseId");
    }

    private String workout(String exerciseId) {
        Instant now = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        // Buổi tập phải nằm trong "hôm nay" giờ Việt Nam, kể cả khi test chạy ngay sau nửa đêm
        Instant midnight = now.atZone(LocalDates.DEFAULT_ZONE).toLocalDate()
            .atStartOfDay(LocalDates.DEFAULT_ZONE).toInstant();
        Instant start = now.minus(12, ChronoUnit.MINUTES).isBefore(midnight) ? midnight : now.minus(12, ChronoUnit.MINUTES);
        Instant end = start.plus(12, ChronoUnit.MINUTES);
        return """
            {"clientId":"buddy-%s","startedAt":"%s","endedAt":"%s","variant":"normal","rpe":6,
             "sets":[{"exerciseId":"%s","setIndex":1,"reps":10}]}"""
            .formatted(UUID.randomUUID().toString().substring(0, 8), start, end, exerciseId);
    }

    @Test
    void invite_join_nudge_workout_leave() throws Exception {
        String exerciseId = onboard(minh, "Minh");
        onboard(lan, "Lan");

        assertEquals("NO_BUDDY", call(get("/buddies/today").header("Authorization", lan), 404).read("$.code"));

        // Minh tạo mã; bấm lại vẫn ra mã cũ
        DocumentContext invite = postJson("/buddies/invites", minh, "", 200);
        String code = invite.read("$.code");
        assertTrue(code.matches("[A-HJ-NP-Z2-9]{6}"), code);
        assertTrue(invite.<String>read("$.shareText").contains(code));
        assertEquals(code, postJson("/buddies/invites", minh, "", 200).read("$.code"));

        assertEquals("OWN_INVITE", postJson("/buddies/join", minh, "{\"code\":\"%s\"}".formatted(code), 400)
            .read("$.code"));
        assertEquals("INVITE_NOT_FOUND", postJson("/buddies/join", lan, "{\"code\":\"000000\"}", 404).read("$.code"));

        // Lan nhập mã (gõ chữ thường)
        DocumentContext pair = postJson("/buddies/join", lan,
            "{\"code\":\"%s\"}".formatted(code.toLowerCase()), 200);
        String pairId = pair.read("$.pairId");
        assertEquals("Minh", pair.read("$.buddyName"));
        assertEquals("INVITE_USED", postJson("/buddies/join", lan, "{\"code\":\"%s\"}".formatted(code), 410)
            .read("$.code"));
        assertEquals("ALREADY_PAIRED", postJson("/buddies/invites", minh, "", 409).read("$.code"));

        ObjectId minhId = userId(minh);
        ObjectId lanId = userId(lan);
        Document stored = mongo.findById(new ObjectId(pairId), Document.class, "buddy_pairs");
        String smaller = minhId.toHexString().compareTo(lanId.toHexString()) < 0 ? minhId.toHexString()
            : lanId.toHexString();
        assertTrue(stored.getString("pairKey").startsWith(smaller + "_"));

        // Lan xem Minh hôm nay: chưa tập
        DocumentContext today = call(get("/buddies/today").header("Authorization", lan), 200);
        assertEquals(pairId, today.read("$.pairId"));
        assertEquals("Minh", today.read("$.buddy.displayName"));
        assertTrue(Set.of("planned", "rest", "none").contains(today.<String>read("$.buddy.status")));
        assertEquals(0, today.<Integer>read("$.buddy.week.completedSessions"));
        assertFalse(today.<Boolean>read("$.myActionsToday.nudged"));
        assertFalse(today.jsonString().contains("\"shared\""));         // mặc định không chia sẻ gì thêm
        assertFalse(today.jsonString().contains("weight"));

        // Nhắc 1 lần/ngày
        assertEquals("nudge", postJson("/buddies/" + pairId + "/actions", lan, "{\"type\":\"nudge\"}", 200)
            .read("$.type"));
        assertEquals("ALREADY_NUDGED", postJson("/buddies/" + pairId + "/actions", lan,
            "{\"type\":\"nudge\",\"message\":\"Tập đi!\"}", 409).read("$.code"));
        assertTrue(call(get("/buddies/today").header("Authorization", lan), 200)
            .<Boolean>read("$.myActionsToday.nudged"));

        // Người ngoài cặp không gửi được
        String stranger = "Bearer dev-it-" + UUID.randomUUID();
        try {
            onboard(stranger, "Lạ");
            assertEquals("PAIR_NOT_FOUND", postJson("/buddies/" + pairId + "/actions", stranger,
                "{\"type\":\"cheer\"}", 404).read("$.code"));
        } finally {
            ObjectId strangerId = userId(stranger);
            mongo.remove(Query.query(Criteria.where("userId").is(strangerId)), "training_plans");
            mongo.remove(Query.query(Criteria.where("userId").is(strangerId)), "weekly_streaks");
            mongo.remove(Query.query(Criteria.where("_id").is(strangerId)), "users");
        }

        // Minh tập xong: Lan thấy "done", không nhắc được nữa, vẫn cổ vũ được
        postJson("/workouts", minh, workout(exerciseId), 200);
        DocumentContext done = call(get("/buddies/today").header("Authorization", lan), 200);
        assertEquals("done", done.read("$.buddy.status"));
        assertEquals(1, done.<Integer>read("$.buddy.week.completedSessions"));
        assertEquals("BUDDY_DONE", postJson("/buddies/" + pairId + "/actions", lan, "{\"type\":\"nudge\"}", 409)
            .read("$.code"));
        postJson("/buddies/" + pairId + "/actions", lan, "{\"type\":\"cheer\",\"message\":\"Đỉnh quá!\"}", 200);
        assertEquals("ALREADY_CHEERED", postJson("/buddies/" + pairId + "/actions", lan, "{\"type\":\"cheer\"}", 409)
            .read("$.code"));
        assertTrue(call(get("/buddies/today").header("Authorization", lan), 200)
            .<Boolean>read("$.myActionsToday.cheered"));

        // Lan rời cặp
        call(delete("/buddies/pair").header("Authorization", lan), 204);
        assertEquals("NO_BUDDY", call(get("/buddies/today").header("Authorization", lan), 404).read("$.code"));
        assertEquals("NO_BUDDY", call(get("/buddies/today").header("Authorization", minh), 404).read("$.code"));
        assertEquals("PAIR_NOT_FOUND", postJson("/buddies/" + pairId + "/actions", minh, "{\"type\":\"cheer\"}", 404)
            .read("$.code"));
        assertEquals("ended", mongo.findById(new ObjectId(pairId), Document.class, "buddy_pairs").getString("status"));
        call(delete("/buddies/pair").header("Authorization", lan), 404);
    }

    @Test
    void expired_invite_is_refused() throws Exception {
        onboard(minh, "Minh");
        onboard(lan, "Lan");
        String code = BuddyRules.newCode(new java.security.SecureRandom());
        mongo.insert(new Document("inviterId", userId(minh)).append("code", code)
            .append("expiresAt", Date.from(Instant.now().minus(1, ChronoUnit.HOURS)))
            .append("createdAt", Date.from(Instant.now().minus(8, ChronoUnit.DAYS))), "buddy_invites");

        assertEquals("INVITE_EXPIRED", postJson("/buddies/join", lan, "{\"code\":\"%s\"}".formatted(code), 410)
            .read("$.code"));
        // Mã hết hạn không còn được trả lại: tạo mã mới
        String fresh = postJson("/buddies/invites", minh, "", 200).read("$.code");
        assertFalse(fresh.equals(code));
    }
}
