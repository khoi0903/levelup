package vn.levelup.plans;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.util.List;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;

import com.jayway.jsonpath.DocumentContext;

import vn.levelup.FlowTestBase;

/** Người dùng đổi bài không thích: gợi ý bài an toàn, đổi trong buổi, nhớ để tuần sau không xếp lại. */
@SpringBootTest
@ActiveProfiles("dev")
class ExerciseSwapFlowTest extends FlowTestBase {

    private DocumentContext swap(String sessionId, String body, int expected) throws Exception {
        return call(post("/plans/sessions/" + sessionId + "/swap").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(body), expected);
    }

    @Test
    void alternatives_then_swap_and_remember() throws Exception {
        DocumentContext plan = onboard();
        String sessionId = plan.read("$.plan.sessions[0].id");
        List<String> inSession = plan.read("$.plan.sessions[0].items[*].exerciseId");
        String from = inSession.getFirst();

        DocumentContext alts = call(get("/plans/sessions/" + sessionId + "/alternatives")
            .param("exerciseId", from).header("Authorization", token), 200);
        List<String> altIds = alts.read("$[*].exerciseId");
        assertFalse(altIds.isEmpty(), "có bài thay thế");
        assertTrue(altIds.size() <= ExerciseSwapService.MAX_ALTERNATIVES);
        altIds.forEach(id -> assertFalse(inSession.contains(id), "không gợi ý bài đã có trong buổi"));
        assertTrue(alts.<String>read("$[0].nameVi").length() > 0);

        // Bài đã có trong buổi / bài không thuộc buổi → từ chối
        assertEquals("EXERCISE_NOT_ALLOWED", swap(sessionId,
            "{\"fromExerciseId\":\"%s\",\"toExerciseId\":\"%s\"}".formatted(from, inSession.getLast()), 400)
            .read("$.code"));
        assertEquals("EXERCISE_NOT_IN_SESSION", swap(sessionId,
            "{\"fromExerciseId\":\"%s\",\"toExerciseId\":\"%s\"}".formatted(altIds.getFirst(), altIds.getFirst()), 400)
            .read("$.code"));

        String to = altIds.getFirst();
        DocumentContext after = swap(sessionId,
            "{\"fromExerciseId\":\"%s\",\"toExerciseId\":\"%s\",\"remember\":true}".formatted(from, to), 200);
        List<String> newItems = after.read("$.sessions[?(@.id == '" + sessionId + "')].items[*].exerciseId");
        assertTrue(newItems.contains(to));
        assertFalse(newItems.contains(from));
        assertEquals(inSession.size(), newItems.size(), "giữ số bài trong buổi");

        Document user = user();
        assertTrue(user.getList("exerciseDislikes", ObjectId.class).contains(new ObjectId(from)));
        // Bài đã bỏ không còn được gợi ý lại
        List<String> again = call(get("/plans/sessions/" + sessionId + "/alternatives")
            .param("exerciseId", to).header("Authorization", token), 200).read("$[*].exerciseId");
        assertFalse(again.contains(from));
    }
}
