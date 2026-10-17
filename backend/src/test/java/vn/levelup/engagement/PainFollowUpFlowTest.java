package vn.levelup.engagement;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

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


/** Báo đau sau buổi tập → hỏi thăm hôm sau (GET /me.painFollowUps, POST /pain-followups/{area}). */
@SpringBootTest
@ActiveProfiles("dev")
class PainFollowUpFlowTest extends FlowTestBase {

    private int clients = 0;

    private void workout(DocumentContext onboarding, String painType) throws Exception {
        String exerciseId = onboarding.read("$.plan.sessions[0].items[0].exerciseId");
        Instant end = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        String type = painType == null ? "" : ",\"painType\":\"" + painType + "\"";
        String body = """
            {"clientId":"pain-client-%d","startedAt":"%s","endedAt":"%s","variant":"normal","rpe":7,
             "painAreas":["knee"]%s,"sets":[{"exerciseId":"%s","setIndex":1,"reps":10}]}"""
            .formatted(++clients, end.minus(12, ChronoUnit.MINUTES), end, type, exerciseId);
        call(post("/workouts").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content(body), 200);
    }

    private DocumentContext answer(String area, String answer, int expected) throws Exception {
        return call(post("/pain-followups/" + area).header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content("{\"answer\":\"" + answer + "\"}"), expected);
    }

    private List<Object> dueAreas() throws Exception {
        return call(get("/me").header("Authorization", token), 200).read("$.painFollowUps[*].bodyArea");
    }

    private Document knee() {
        return user().getList("injuries", Document.class).stream()
            .filter(i -> "knee".equals(i.getString("bodyArea"))).findFirst().orElseThrow();
    }

    /** Lùi ngày báo đau (và ngày trả lời) để giả lập "hôm sau". */
    private void shift(int reportedDaysAgo, Integer answeredDaysAgo) {
        LocalDate today = LocalDate.parse(knee().getString("reportedOn"));
        Update u = new Update().set("injuries.$.reportedOn", today.minusDays(reportedDaysAgo).toString());
        if (answeredDaysAgo != null) {
            u.set("injuries.$.lastAnswerOn", today.minusDays(answeredDaysAgo).toString());
        }
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId()).and("injuries.bodyArea").is("knee")), u,
            "users");
    }

    @Test
    void sharp_pain_is_watched_and_swapped_out_of_remaining_sessions() throws Exception {
        DocumentContext onboarding = onboard();
        workout(onboarding, "sharp");

        Document knee = knee();
        assertTrue(knee.getBoolean("active"));
        assertTrue(knee.getBoolean("followUp"));
        assertEquals(List.of(), dueAreas(), "hôm báo đau chưa hỏi thăm");

        // Không còn buổi planned nào có bài chống chỉ định với đầu gối
        Set<ObjectId> kneeBad = mongo.find(Query.query(Criteria.where("contraindications").is("knee")),
            Document.class, "exercises").stream().map(e -> e.getObjectId("_id")).collect(Collectors.toSet());
        Document plan = mongo.findOne(Query.query(Criteria.where("userId").is(userId()).and("status").is("active")),
            Document.class, "training_plans");
        for (Document s : plan.getList("sessions", Document.class)) {
            if (!"planned".equals(s.getString("status"))) {
                continue;
            }
            for (Document item : s.getList("items", Document.class)) {
                assertFalse(kneeBad.contains(item.getObjectId("exerciseId")), "còn bài hại gối");
            }
        }

        shift(1, null);
        assertEquals(List.of("knee"), dueAreas());
        DocumentContext r = answer("knee", "same", 200);
        assertEquals("monitoring", r.read("$.status"));
        assertFalse(r.<String>read("$.message").isBlank());
        assertEquals(List.of(), dueAreas(), "đã trả lời hôm nay");

        // Vẫn đau sau 3 ngày: thành chấn thương, không hỏi nữa nhưng vẫn tránh vùng này
        shift(3, 1);
        assertEquals("injury", answer("knee", "same", 200).read("$.status"));
        assertFalse(knee().getBoolean("followUp"));
        assertTrue(knee().getBoolean("active"));
        answer("knee", "same", 404);
        assertEquals(List.of("knee"),
            call(get("/me").header("Authorization", token), 200).read("$.activeInjuries[*].bodyArea"));
        // Chấn thương vẫn báo "đã khỏi" được
        assertEquals("resolved", answer("knee", "gone", 200).read("$.status"));
        assertFalse(knee().getBoolean("active"));
    }

    @Test
    void gone_resolves_and_worse_becomes_injury() throws Exception {
        DocumentContext onboarding = onboard();
        workout(onboarding, "sharp");
        shift(1, null);
        assertEquals("resolved", answer("knee", "gone", 200).read("$.status"));
        assertFalse(knee().getBoolean("active"));
        assertEquals(List.of(), dueAreas());
        answer("knee", "same", 404);

        workout(onboarding, "sharp");
        Document watch = user().getList("injuries", Document.class).stream()
            .filter(i -> "knee".equals(i.getString("bodyArea")) && i.getBoolean("active")).findFirst().orElseThrow();
        assertTrue(watch.getBoolean("followUp"));
        assertEquals("injury", answer("knee", "worse", 200).read("$.status"));
    }

    @Test
    void soreness_is_not_watched() throws Exception {
        DocumentContext onboarding = onboard();
        workout(onboarding, "soreness");
        assertTrue(user().getList("injuries", Document.class).isEmpty());
        answer("knee", "gone", 404);
        assertEquals(List.of(), call(get("/me").header("Authorization", token), 200).read("$.activeInjuries"));
        answer("knee", "maybe", 400);
    }
}
