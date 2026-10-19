package vn.levelup.coach;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;

import org.bson.Document;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import com.jayway.jsonpath.DocumentContext;
import vn.levelup.FlowTestBase;
import vn.levelup.coach.ai.AiClient;

/** POST /coach/voice-line: Pro được câu AI, còn lại câu mẫu; AI lỗi vẫn trả câu mẫu. */
@SpringBootTest
@ActiveProfiles("dev")
class VoiceLineFlowTest extends FlowTestBase {

    private static final String BODY = """
        {"situation":"idle_prompt","exerciseName":"Squat","repsDone":3,"targetReps":12,"formIssues":["knees_in"]}""";

    @MockitoBean AiClient ai;

    private DocumentContext ask(String body, int expected) throws Exception {
        return call(post("/coach/voice-line").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content(body), expected);
    }

    private void makePro() {
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId())), Update.update("plan",
            new Document("tier", "pro").append("expiresAt", Date.from(Instant.now().plus(30, ChronoUnit.DAYS)))),
            "users");
    }

    @Test
    void free_user_gets_template_without_calling_ai() throws Exception {
        onboard();
        when(ai.available()).thenReturn(true);
        DocumentContext r = ask(BODY, 200);
        assertFalse(r.<Boolean>read("$.ai"));
        assertTrue(r.<String>read("$.text").contains("ẫy tay"));
        verify(ai, never()).complete(anyString(), any(), anyInt());
    }

    @Test
    void pro_user_gets_cleaned_ai_line_and_falls_back_when_ai_fails() throws Exception {
        onboard();
        makePro();
        when(ai.available()).thenReturn(true);
        when(ai.complete(anyString(), any(), anyInt())).thenReturn("\"Squat hơi khó đúng không? Nghỉ chút nhé.\"");
        DocumentContext r = ask(BODY, 200);
        assertTrue(r.<Boolean>read("$.ai"));
        assertEquals("Squat hơi khó đúng không? Nghỉ chút nhé. Vẫy tay nếu muốn bỏ qua.", r.read("$.text"));

        when(ai.complete(anyString(), any(), anyInt()))
            .thenThrow(new AiClient.AiUnavailableException("timeout", null));
        assertFalse(ask(BODY, 200).<Boolean>read("$.ai"));
    }

    @Test
    void rejects_bad_input() throws Exception {
        onboard();
        ask("{\"situation\":\"hack\",\"exerciseName\":\"Squat\"}", 400);
        ask("{\"situation\":\"skipped\",\"exerciseName\":\"\"}", 400);
    }
}
