package vn.levelup.engagement;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import jakarta.servlet.Filter;

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
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.RequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import com.jayway.jsonpath.DocumentContext;
import com.jayway.jsonpath.JsonPath;
import vn.levelup.coach.ai.AiClient;
import vn.levelup.engagement.service.WeeklyReviewService;
import vn.levelup.shared.util.LocalDates;


/**
 * Tổng kết tuần (F6) trên MongoDB dev: tập một buổi → tạo tổng kết → xem → đồng ý kế hoạch tuần sau.
 * AiClient là mock: không bao giờ gọi Claude thật.
 */
@SpringBootTest
@ActiveProfiles("dev")
class ReviewFlowTest {

    @Autowired WebApplicationContext context;
    @Autowired MongoTemplate mongo;
    @Autowired WeeklyReviewService reviews;
    @MockitoBean AiClient ai;

    MockMvc mvc;
    String token;

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.webAppContextSetup(context)
            .addFilters(context.getBean("springSecurityFilterChain", Filter.class)).build();
        token = "Bearer dev-it-" + UUID.randomUUID();
    }

    @AfterEach
    void cleanUp() {
        Document user = userDoc();
        if (user == null) {
            return;
        }
        Query mine = Query.query(Criteria.where("userId").is(user.getObjectId("_id")));
        for (String c : new String[] {"workout_logs", "training_plans", "weekly_streaks", "personal_records",
                                      "daily_stats", "coach_messages", "weekly_reviews"}) {
            mongo.remove(mine, c);
        }
        mongo.remove(Query.query(Criteria.where("_id").is(user.getObjectId("_id"))), "users");
    }

    private Document userDoc() {
        return mongo.findOne(Query.query(Criteria.where("authUid").is(token.substring("Bearer dev-".length()))),
            Document.class, "users");
    }

    private DocumentContext call(RequestBuilder req, int expected) throws Exception {
        String body = mvc.perform(req).andExpect(status().is(expected)).andReturn().getResponse()
            .getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        return JsonPath.parse(body);
    }

    private DocumentContext onboard() throws Exception {
        String body = """
            {"displayName":"Lan","goal":"get_healthier","gender":"female","birthYear":1998,"heightCm":158,
             "weightKg":52,"experience":"beginner","location":"home","equipment":[],"injuries":[],
             "availability":[{"weekday":1,"slot":"evening"},{"weekday":2,"slot":"evening"},
               {"weekday":3,"slot":"evening"},{"weekday":4,"slot":"evening"},{"weekday":5,"slot":"evening"},
               {"weekday":6,"slot":"evening"},{"weekday":7,"slot":"evening"}],
             "sessionMinutes":15,"coachStyle":"funny","timezone":"Asia/Ho_Chi_Minh"}""";
        return call(post("/onboarding").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content(body), 200);
    }

    @Test
    void tao_tong_ket_xem_va_dong_y() throws Exception {
        when(ai.available()).thenReturn(true);
        when(ai.complete(anyString(), anyList(), anyInt()))
            .thenThrow(new AiClient.AiUnavailableException("Coach đang bận, thử lại nhé", null));
        DocumentContext onboarding = onboard();
        assertEquals("NO_REVIEW", call(get("/reviews/latest").header("Authorization", token), 404).read("$.code"));

        // Tập buổi đầu của kế hoạch
        Map<String, Object> first = onboarding.read("$.plan.sessions[0]");
        String exerciseId = onboarding.read("$.plan.sessions[0].items[0].exerciseId");
        Instant end = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        String workout = """
            {"clientId":"client-review-1","plannedSessionId":"%s","startedAt":"%s","endedAt":"%s",
             "variant":"normal","rpe":6,"sets":[{"exerciseId":"%s","setIndex":1,"reps":10}]}"""
            .formatted(first.get("id"), end.minus(12, ChronoUnit.MINUTES), end, exerciseId);
        call(post("/workouts").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content(workout), 200);

        ObjectId userId = userDoc().getObjectId("_id");
        String weekStart = onboarding.read("$.plan.weekStart");
        Document review = reviews.generate(userId, weekStart);
        reviews.onWeekClosed(userId, weekStart);                       // chạy lại: không tạo thêm
        assertEquals(1, mongo.count(Query.query(Criteria.where("userId").is(userId)), "weekly_reviews"));
        assertEquals(1, mongo.count(Query.query(Criteria.where("userId").is(userId).and("status").is("draft")),
            "training_plans"));

        String nextWeek = LocalDates.weekStart(java.time.LocalDate.parse(weekStart)).plusWeeks(1).toString();
        DocumentContext latest = call(get("/reviews/latest").header("Authorization", token), 200);
        assertEquals(review.getObjectId("_id").toHexString(), latest.read("$.id"));
        assertEquals(1, latest.<Integer>read("$.sessionsDone"));
        assertEquals("rules", latest.read("$.source"));
        assertEquals("pending", latest.read("$.decision"));
        assertNotNull(latest.read("$.win"));
        assertNotNull(latest.read("$.improvement"));
        assertEquals("draft", latest.read("$.plan.status"));
        assertEquals(nextWeek, latest.read("$.plan.weekStart"));
        List<String> dates = latest.read("$.plan.sessions[*].scheduledDate");
        assertTrue(!dates.isEmpty() && dates.stream().allMatch(d -> d.compareTo(nextWeek) >= 0));
        assertTrue(List.of("increase", "keep", "decrease").contains(latest.<String>read("$.recommendation")));

        String reviewId = latest.read("$.id");
        DocumentContext bad = call(post("/reviews/" + reviewId + "/decision").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content("{\"decision\":\"adjusted\"}"), 400);
        assertEquals("ADJUSTMENTS_REQUIRED", bad.read("$.code"));

        DocumentContext plan = call(post("/reviews/" + reviewId + "/decision").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content("{\"decision\":\"accepted\"}"), 200);
        assertEquals("active", plan.read("$.status"));
        assertEquals(nextWeek, plan.read("$.weekStart"));
        int target = plan.read("$.targetSessions");

        Document streak = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(nextWeek)),
            Document.class, "weekly_streaks");
        assertEquals(target, ((Number) streak.get("targetSessions")).intValue());
        assertEquals("accepted", call(get("/reviews/latest").header("Authorization", token), 200).read("$.decision"));
        assertEquals("REVIEW_DECIDED", call(post("/reviews/" + reviewId + "/decision").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content("{\"decision\":\"accepted\"}"), 409).read("$.code"));
        // Chỉ một kế hoạch active cho tuần sau
        assertEquals(1, mongo.count(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(nextWeek)
            .and("status").is("active")), "training_plans"));
    }

    @Test
    void ai_viet_loi_tong_ket_va_nguoi_dung_chinh_ke_hoach() throws Exception {
        when(ai.available()).thenReturn(true);
        when(ai.complete(anyString(), anyList(), anyInt())).thenReturn(
            "{\"win\":\"Bạn đã bắt đầu 🎉\",\"improve\":\"Thêm một buổi nhé\",\"nextWeekSummary\":\"Tuần sau nhẹ nhàng\"}");
        DocumentContext onboarding = onboard();
        ObjectId userId = userDoc().getObjectId("_id");
        reviews.generate(userId, onboarding.read("$.plan.weekStart"));

        DocumentContext latest = call(get("/reviews/latest").header("Authorization", token), 200);
        assertEquals("ai", latest.read("$.source"));
        assertEquals("Bạn đã bắt đầu 🎉", latest.read("$.win"));
        assertEquals("decrease", latest.read("$.recommendation"));          // chưa tập buổi nào

        DocumentContext plan = call(post("/reviews/" + latest.read("$.id") + "/decision")
            .header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"decision\":\"adjusted\",\"adjustments\":{\"sessionsPerWeek\":2,\"sessionMinutes\":20}}"), 200);
        assertEquals("active", plan.read("$.status"));
        assertTrue(plan.<Integer>read("$.sessions.length()") <= 2);
        assertTrue(plan.<List<Integer>>read("$.sessions[*].durationMin").stream().allMatch(m -> m == 20));
        assertEquals(plan.<Integer>read("$.sessions.length()"), plan.<Integer>read("$.targetSessions"));

        Document review = mongo.findOne(Query.query(Criteria.where("userId").is(userId)), Document.class,
            "weekly_reviews");
        assertEquals("adjusted", review.getString("decision"));
    }
}
