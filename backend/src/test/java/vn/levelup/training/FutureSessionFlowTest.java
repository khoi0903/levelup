package vn.levelup.training;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.time.Instant;
import java.time.LocalDate;
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
import vn.levelup.shared.util.LocalDates;
import vn.levelup.FlowTestBase;


/** Tập trước buổi của ngày sau không được đánh dấu buổi đó hoàn thành (lỗi Chủ nhật → buổi Thứ Hai). */
@SpringBootTest
@ActiveProfiles("dev")
class FutureSessionFlowTest extends FlowTestBase {

    @Test
    void workout_linked_to_future_session_is_logged_but_session_stays_planned() throws Exception {
        String exerciseId = onboard().read("$.plan.sessions[0].items[0].exerciseId");
        ObjectId me = userId();
        LocalDate tomorrow = LocalDate.now(LocalDates.DEFAULT_ZONE).plusDays(1);

        // Một kế hoạch active có buổi ngày mai (có thể thuộc tuần sau)
        ObjectId futureSession = new ObjectId();
        Document item = new Document("exerciseId", new ObjectId(exerciseId)).append("targetSets", 2)
            .append("targetReps", 10).append("restSec", 45);
        mongo.updateMulti(Query.query(Criteria.where("userId").is(me)), new Update().set("status", "replaced"),
            "training_plans");
        mongo.insert(new Document("userId", me)
            .append("weekStart", LocalDates.weekStart(tomorrow).toString())
            .append("status", "active").append("targetSessions", 1).append("createdBy", "rule")
            .append("sessions", List.of(new Document("_id", futureSession)
                .append("scheduledDate", tomorrow.toString()).append("scheduledTime", "18:30")
                .append("title", "Buổi ngày mai").append("durationMin", 15).append("variant", "normal")
                .append("status", "planned").append("items", List.of(item))))
            .append("createdAt", new java.util.Date()), "training_plans");

        Instant end = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        String body = """
            {"clientId":"future-%s","plannedSessionId":"%s","startedAt":"%s","endedAt":"%s","variant":"normal",
             "sets":[{"exerciseId":"%s","setIndex":1,"reps":10}]}"""
            .formatted(uid.substring(3, 15), futureSession.toHexString(), end.minus(10, ChronoUnit.MINUTES), end,
                exerciseId);
        call(post("/workouts").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content(body), 200);

        Document plan = mongo.findOne(Query.query(Criteria.where("userId").is(me).and("status").is("active")),
            Document.class, "training_plans");
        assertEquals("planned", plan.getList("sessions", Document.class).getFirst().getString("status"));
        Document log = mongo.findOne(Query.query(Criteria.where("userId").is(me)), Document.class, "workout_logs");
        assertFalse(log.containsKey("plannedSessionId"));            // tính là tập thêm
    }
}
