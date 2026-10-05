package vn.levelup.workouts;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
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
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

import com.jayway.jsonpath.DocumentContext;
import com.jayway.jsonpath.JsonPath;

/**
 * Chạy trên MongoDB dev (localhost:27018, cần docker compose up và seed bài tập):
 * onboarding → lưu buổi → gửi lại cùng clientId → streak. Dọn dữ liệu của người dùng thử sau mỗi test.
 */
@SpringBootTest
@ActiveProfiles("dev")
class WorkoutFlowTest {

    @Autowired WebApplicationContext context;
    @Autowired MongoTemplate mongo;

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
        Document user = mongo.findOne(Query.query(Criteria.where("authUid").is(token.substring("Bearer dev-".length()))),
            Document.class, "users");
        if (user == null) {
            return;
        }
        Query mine = Query.query(Criteria.where("userId").is(user.getObjectId("_id")));
        for (String c : new String[] {"workout_logs", "training_plans", "weekly_streaks", "personal_records",
                                      "daily_stats"}) {
            mongo.remove(mine, c);
        }
        mongo.remove(Query.query(Criteria.where("_id").is(user.getObjectId("_id"))), "users");
    }

    private DocumentContext call(org.springframework.test.web.servlet.RequestBuilder req, int expected)
            throws Exception {
        String body = mvc.perform(req).andExpect(status().is(expected)).andReturn().getResponse()
            .getContentAsString(java.nio.charset.StandardCharsets.UTF_8);
        return JsonPath.parse(body);
    }

    private String onboard() throws Exception {
        String body = """
            {"displayName":"Thử","goal":"lose_fat","gender":"male","birthYear":1995,"heightCm":170,
             "weightKg":70,"experience":"beginner","location":"home","equipment":[],"injuries":[],
             "availability":[{"weekday":1,"slot":"evening"},{"weekday":2,"slot":"evening"},
               {"weekday":3,"slot":"evening"},{"weekday":4,"slot":"evening"},{"weekday":5,"slot":"evening"},
               {"weekday":6,"slot":"evening"},{"weekday":7,"slot":"evening"}],
             "sessionMinutes":15,"coachStyle":"supportive","timezone":"Asia/Ho_Chi_Minh"}""";
        DocumentContext r = call(post("/onboarding").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(body), 200);
        return r.read("$.plan.sessions[0].items[0].exerciseId");
    }

    private String workout(String clientId, String exerciseId, int minutes, int reps) {
        Instant end = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        Instant start = end.minus(minutes, ChronoUnit.MINUTES);
        return """
            {"clientId":"%s","startedAt":"%s","endedAt":"%s","variant":"normal","rpe":6,
             "sets":[{"exerciseId":"%s","setIndex":1,"reps":%d},{"exerciseId":"%s","setIndex":2,"reps":%d}]}"""
            .formatted(clientId, start, end, exerciseId, reps, exerciseId, reps - 2);
    }

    @Test
    void save_resend_and_streak() throws Exception {
        String exerciseId = onboard();

        DocumentContext first = call(post("/workouts").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(workout("client-aaa-1", exerciseId, 12, 10)), 200);
        assertTrue(first.<Boolean>read("$.countsForStreak"));
        assertTrue(first.<Integer>read("$.kcalBurned") > 0, "có ước tính calo đốt");
        assertFalse(first.<Boolean>read("$.duplicate"));
        assertEquals(1, first.<Integer>read("$.week.completedSessions"));
        assertEquals(0, first.<Integer>read("$.personalRecords.length()"));     // lần đầu chỉ lưu mốc
        assertEquals("sessions_1", first.read("$.newAchievements[0].code"));

        // App gửi lại: cùng kết quả, không lưu trùng
        DocumentContext again = call(post("/workouts").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(workout("client-aaa-1", exerciseId, 12, 10)), 200);
        assertTrue(again.<Boolean>read("$.duplicate"));
        assertEquals(first.<Integer>read("$.kcalBurned"), again.<Integer>read("$.kcalBurned"));   // gửi lại: cùng số
        assertEquals(first.<String>read("$.workoutId"), again.read("$.workoutId"));
        assertEquals(1, again.<Integer>read("$.week.completedSessions"));
        assertEquals("sessions_1", again.read("$.newAchievements[0].code"));

        // Buổi thứ hai vượt số lần: kỷ lục mới; buổi 3 phút không tính streak
        DocumentContext second = call(post("/workouts").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(workout("client-aaa-2", exerciseId, 10, 14)), 200);
        assertEquals("max_reps", second.read("$.personalRecords[0].metric"));
        assertEquals(14.0, second.<Double>read("$.personalRecords[0].value"));
        assertEquals(10.0, second.<Double>read("$.personalRecords[0].previous"));
        DocumentContext shortOne = call(post("/workouts").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(workout("client-aaa-3", exerciseId, 3, 5)), 200);
        assertFalse(shortOne.<Boolean>read("$.countsForStreak"));
        assertEquals(2, shortOne.<Integer>read("$.week.completedSessions"));

        Document user = mongo.findOne(Query.query(Criteria.where("authUid").is(token.substring(11))),
            Document.class, "users");
        ObjectId userId = user.getObjectId("_id");
        assertEquals(3, mongo.count(Query.query(Criteria.where("userId").is(userId)), "workout_logs"));
        assertEquals("active", ((Document) user.get("reengagement")).getString("stage"));

        DocumentContext streak = call(get("/streak").header("Authorization", token), 200);
        assertEquals(1, streak.<Integer>read("$.weeks.length()"));   // người mới: chỉ tuần này, không 7 tuần trống
        assertEquals(2, streak.<Integer>read("$.thisWeek.completedSessions"));
    }

    @Test
    void unknown_exercise_and_bad_time_are_rejected() throws Exception {
        onboard();
        DocumentContext unknown = call(post("/workouts").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(workout("client-bbb-1", "0".repeat(24), 10, 5)), 400);
        assertEquals("UNKNOWN_EXERCISE", unknown.read("$.code"));

        String reversed = """
            {"clientId":"client-bbb-2","startedAt":"2026-10-03T10:00:00Z","endedAt":"2026-10-03T09:00:00Z",
             "variant":"normal","sets":[{"exerciseId":"%s","setIndex":1,"reps":5}]}""".formatted("0".repeat(24));
        DocumentContext time = call(post("/workouts").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(reversed), 400);
        assertEquals("INVALID_TIME", time.read("$.code"));
    }
}
