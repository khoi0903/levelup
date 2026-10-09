package vn.levelup.identity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;

import vn.levelup.FlowTestBase;

/** DELETE /me xoá toàn bộ dữ liệu của người dùng, không đụng dữ liệu người khác (yêu cầu Google Play). */
@SpringBootTest
@ActiveProfiles("dev")
class DeleteAccountFlowTest extends FlowTestBase {

    @Test
    void delete_me_removes_all_user_data_only() throws Exception {
        String exerciseId = onboard().read("$.plan.sessions[0].items[0].exerciseId");
        ObjectId me = userId();
        ObjectId other = new ObjectId();

        // Dữ liệu qua API: check-in, buổi tập, tin coach
        call(post("/checkins").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"energy\":\"normal\"}"), 200);
        Instant end = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        call(post("/workouts").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"clientId":"del-%s","startedAt":"%s","endedAt":"%s","variant":"normal",
                 "sets":[{"exerciseId":"%s","setIndex":1,"reps":10}]}"""
                .formatted(uid.substring(4, 16), end.minus(10, ChronoUnit.MINUTES), end, exerciseId)), 200);
        call(post("/coach/messages").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"text\":\"xin chào\"}"), 200);
        // Buddy và dữ liệu của người khác (phải còn nguyên)
        mongo.insert(new Document("members", List.of(me, other)).append("pairKey", me + "|" + other)
            .append("status", "active"), "buddy_pairs");
        mongo.insert(new Document("userId", other).append("measuredOn", "2026-10-01").append("weightKg", 60),
            "body_measurements");

        call(delete("/me").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"confirm\":false}"), 400);                     // phải xác nhận rõ ràng
        mvc.perform(delete("/me").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"confirm\":true}")).andExpect(r -> assertEquals(204, r.getResponse().getStatus()));

        assertEquals(0, mongo.count(Query.query(Criteria.where("_id").is(me)), "users"));
        for (String c : List.of("training_plans", "workout_logs", "daily_stats", "coach_messages", "weekly_streaks",
            "personal_records")) {
            assertEquals(0, mongo.count(Query.query(Criteria.where("userId").is(me)), c), c);
        }
        assertEquals(0, mongo.count(Query.query(Criteria.where("members").is(me)), "buddy_pairs"));
        assertTrue(mongo.count(Query.query(Criteria.where("userId").is(other)), "body_measurements") == 1,
            "dữ liệu người khác còn nguyên");
        // Đăng nhập lại bằng token cũ: như người mới, phải onboarding lại
        call(get("/me").header("Authorization", token), 404);

        mongo.remove(Query.query(Criteria.where("userId").is(other)), "body_measurements");
    }

    @Test
    void privacy_and_delete_pages_are_public() throws Exception {
        for (String page : List.of("/privacy.html", "/delete-account.html")) {
            mvc.perform(get(page)).andExpect(r -> {
                assertEquals(200, r.getResponse().getStatus(), page);
                assertTrue(r.getResponse().getContentAsString(java.nio.charset.StandardCharsets.UTF_8)
                    .contains("LevelUp"), page);
            });
        }
    }
}
