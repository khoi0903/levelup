package vn.levelup.workouts;

import static org.junit.jupiter.api.Assertions.assertEquals;
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
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;

import com.jayway.jsonpath.DocumentContext;

import vn.levelup.FlowTestBase;

/** Lưu buổi với RPE thấp: buổi planned kế tiếp thêm 1 hiệp; gửi lại cùng clientId không chỉnh lần nữa. */
@SpringBootTest
@ActiveProfiles("dev")
class RpeFlowTest extends FlowTestBase {

    @Test
    void easy_workout_makes_next_session_harder_once() throws Exception {
        DocumentContext onboarding = onboard();
        String first = onboarding.read("$.plan.sessions[0].id");
        String exerciseId = onboarding.read("$.plan.sessions[0].items[0].exerciseId");
        int setsBefore = onboarding.read("$.plan.sessions[0].items[0].sets");

        // Kế hoạch chỉ còn buổi đầu và một buổi Chủ nhật 23:59, để luôn có đúng một "buổi kế tiếp"
        // (kể cả khi chạy test vào Chủ nhật)
        ObjectId userId = userId();
        Query plan = Query.query(Criteria.where("userId").is(userId).and("status").is("active"));
        Document planDoc = mongo.findOne(plan, Document.class, "training_plans");
        Document copy = new Document(planDoc.getList("sessions", Document.class).getFirst());
        copy.put("_id", new ObjectId());
        copy.put("scheduledDate", java.time.LocalDate.parse(planDoc.getString("weekStart")).plusDays(6).toString());
        copy.put("scheduledTime", "23:59");
        mongo.updateFirst(plan, Update.update("sessions",
            List.of(planDoc.getList("sessions", Document.class).getFirst(), copy)), "training_plans");
        String next = copy.getObjectId("_id").toHexString();

        Instant end = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        String body = """
            {"clientId":"rpe-client-1","plannedSessionId":"%s","startedAt":"%s","endedAt":"%s","variant":"normal",
             "rpe":4,"sets":[{"exerciseId":"%s","setIndex":1,"reps":10}]}"""
            .formatted(first, end.minus(12, ChronoUnit.MINUTES), end, exerciseId);
        for (int i = 0; i < 2; i++) {
            call(post("/workouts").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
                .content(body), 200);
        }

        DocumentContext current = call(get("/plans/current").header("Authorization", token), 200);
        assertEquals("completed", current.read("$.sessions[0].status"));
        List<Integer> sets = current.read("$.sessions[?(@.id == '" + next + "')].items[0].sets");
        assertEquals(List.of(setsBefore + 1), sets);
        List<String> reasons = current.read("$.sessions[?(@.id == '" + next + "')].adjustedReason");
        assertEquals(List.of("rpe_easy"), reasons);
    }
}
