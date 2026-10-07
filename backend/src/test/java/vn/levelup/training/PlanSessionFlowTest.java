package vn.levelup.training;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;

import com.jayway.jsonpath.DocumentContext;
import vn.levelup.FlowTestBase;


/** PATCH /plans/sessions/{id} trên MongoDB dev. */
@SpringBootTest
@ActiveProfiles("dev")
class PlanSessionFlowTest extends FlowTestBase {

    private DocumentContext patchSession(String id, String body, int expected) throws Exception {
        return call(patch("/plans/sessions/" + id).header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(body), expected);
    }

    @Test
    void quick5_then_rest_and_errors() throws Exception {
        DocumentContext onboarding = onboard();
        String sessionId = onboarding.read("$.plan.sessions[0].id");
        String weekStart = onboarding.read("$.plan.weekStart");

        DocumentContext plan = patchSession(sessionId, "{\"action\":\"quick5\"}", 200);
        List<Map<String, Object>> sessions = plan.read("$.sessions[?(@.id == '" + sessionId + "')]");
        Map<String, Object> session = sessions.get(0);
        assertEquals("quick5", session.get("variant"));
        assertEquals(5, session.get("durationMin"));
        assertEquals("user_quick5", session.get("adjustedReason"));
        List<Map<String, Object>> items = (List<Map<String, Object>>) session.get("items");
        assertTrue(!items.isEmpty());
        assertTrue(items.stream().allMatch(i -> Integer.valueOf(1).equals(i.get("sets"))));

        // Ngoài tuần của kế hoạch
        DocumentContext outside = patchSession(sessionId,
            "{\"action\":\"reschedule\",\"scheduledDate\":\"%s\"}".formatted(
                java.time.LocalDate.parse(weekStart).plusDays(7)), 400);
        assertEquals("DATE_OUTSIDE_WEEK", outside.read("$.code"));

        patchSession(sessionId, "{\"action\":\"rest\"}", 200);
        DocumentContext again = patchSession(sessionId, "{\"action\":\"quick5\"}", 409);
        assertEquals("SESSION_NOT_PLANNED", again.read("$.code"));
        patchSession("0".repeat(24), "{\"action\":\"rest\"}", 404);
        patchSession(sessionId, "{\"action\":\"fly\"}", 400);
    }
}
