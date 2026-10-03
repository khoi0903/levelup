package vn.levelup.workouts;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
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
        List<String> ids = onboarding.read("$.plan.sessions[*].id");
        Assumptions.assumeTrue(ids.size() >= 2, "cần ít nhất 2 buổi trong tuần");
        String first = ids.get(0);
        String exerciseId = onboarding.read("$.plan.sessions[0].items[0].exerciseId");
        int setsBefore = onboarding.read("$.plan.sessions[1].items[0].sets");

        Instant end = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        String body = """
            {"clientId":"rpe-client-1","plannedSessionId":"%s","startedAt":"%s","endedAt":"%s","variant":"normal",
             "rpe":4,"sets":[{"exerciseId":"%s","setIndex":1,"reps":10}]}"""
            .formatted(first, end.minus(12, ChronoUnit.MINUTES), end, exerciseId);
        for (int i = 0; i < 2; i++) {
            call(post("/workouts").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
                .content(body), 200);
        }

        DocumentContext plan = call(get("/plans/current").header("Authorization", token), 200);
        assertEquals("completed", plan.read("$.sessions[0].status"));
        assertEquals(setsBefore + 1, plan.<Integer>read("$.sessions[1].items[0].sets"));
        assertEquals("rpe_easy", plan.read("$.sessions[1].adjustedReason"));
    }
}
