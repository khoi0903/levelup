package vn.levelup.engagement;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.util.List;
import java.util.Map;

import org.bson.Document;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;

import com.jayway.jsonpath.DocumentContext;
import vn.levelup.FlowTestBase;


/** POST /skip-reports trên MongoDB dev. */
@SpringBootTest
@ActiveProfiles("dev")
class SkipReportFlowTest extends FlowTestBase {

    private DocumentContext skip(String body, int expected) throws Exception {
        return call(post("/skip-reports").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(body), expected);
    }

    @Test
    void busy_shortens_the_next_session() throws Exception {
        DocumentContext onboarding = onboard();
        String firstId = onboarding.read("$.plan.sessions[0].id");

        DocumentContext r = skip("{\"reason\":\"busy\"}", 200);
        assertEquals("shortened", r.read("$.action"));
        assertFalse(r.<String>read("$.message").isBlank());
        List<Map<String, Object>> sessions = r.read("$.plan.sessions[?(@.id == '" + firstId + "')]");
        assertEquals(10, sessions.get(0).get("durationMin"));
        assertEquals("skip_busy", sessions.get(0).get("adjustedReason"));

        Document report = mongo.findOne(Query.query(Criteria.where("userId").is(userId())), Document.class,
            "skip_reports");
        assertEquals("busy", report.getString("reason"));
        assertEquals("shortened", report.getString("action"));
        assertNotNull(report.getObjectId("planId"));
    }

    @Test
    void pain_requires_body_area_and_adds_injury() throws Exception {
        onboard();
        assertEquals("BODY_AREA_REQUIRED", skip("{\"reason\":\"pain\"}", 400).read("$.code"));

        DocumentContext r = skip("{\"reason\":\"pain\",\"bodyArea\":\"knee\"}", 200);
        assertNotNull(r.read("$.plan"));
        List<Document> injuries = user().getList("injuries", Document.class);
        assertEquals(List.of("knee"), injuries.stream().map(i -> i.getString("bodyArea")).toList());

        DocumentContext forgot = skip("{\"reason\":\"forgot\"}", 200);
        assertEquals("changed_reminder", forgot.read("$.action"));
        assertEquals(60, forgot.<Integer>read("$.suggestion.preWorkoutMinutes"));
    }
}
