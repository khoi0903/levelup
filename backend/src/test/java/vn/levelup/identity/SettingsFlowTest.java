package vn.levelup.identity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

import org.bson.Document;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;

import com.jayway.jsonpath.DocumentContext;
import vn.levelup.FlowTestBase;


/** PATCH /me đổi từng phần, GET /me trả cài đặt mặc định và huy hiệu. Chạy trên MongoDB dev. */
@SpringBootTest
@ActiveProfiles("dev")
class SettingsFlowTest extends FlowTestBase {

    private DocumentContext patchMe(String body, int expected) throws Exception {
        return call(patch("/me").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(body), expected);
    }

    @Test
    void defaults_then_partial_updates_keep_other_fields() throws Exception {
        onboard();
        DocumentContext me = call(get("/me").header("Authorization", token), 200);
        assertTrue(me.<Boolean>read("$.settings.notifications.pushEnabled"));
        assertEquals("22:00", me.read("$.settings.notifications.quietStart"));
        assertEquals("07:00", me.read("$.settings.notifications.quietEnd"));
        assertEquals(2, me.<Integer>read("$.settings.notifications.maxPerDay"));
        assertFalse(me.<Boolean>read("$.settings.notifications.waterReminder"));      // nhắc nước tự bật
        assertFalse(me.<Boolean>read("$.settings.sharing.weight"));
        assertEquals(7, me.<Integer>read("$.settings.availability.length()"));
        assertEquals(0, me.<Integer>read("$.achievements.length()"));

        DocumentContext after = patchMe("""
            {"displayName":"  Khôi  ","coachStyle":"funny",
             "notifications":{"quietStart":"23:00","maxPerDay":1,"waterReminder":true},
             "sharing":{"weight":true}}""", 200);
        assertEquals("Khôi", after.read("$.displayName"));
        assertEquals("funny", after.read("$.profile.coachStyle"));
        assertEquals("23:00", after.read("$.settings.notifications.quietStart"));
        assertEquals("07:00", after.read("$.settings.notifications.quietEnd"));      // không gửi thì giữ
        assertEquals(1, after.<Integer>read("$.settings.notifications.maxPerDay"));
        assertTrue(after.<Boolean>read("$.settings.notifications.waterReminder"));
        assertTrue(after.<Boolean>read("$.settings.sharing.weight"));
        assertFalse(after.<Boolean>read("$.settings.sharing.meals"));
        assertEquals(15, after.<Integer>read("$.profile.sessionMinutes"));            // không gửi thì giữ

        DocumentContext slots = patchMe("""
            {"availability":[{"weekday":5,"slot":"noon"},{"weekday":2,"slot":"evening"}]}""", 200);
        assertEquals(List.of(2, 5), slots.read("$.settings.availability[*].weekday"));
        Document stored = user();
        assertEquals("Khôi", stored.getString("displayName"));
        assertEquals("lose_fat", stored.get("profile", Document.class).getString("goal"), "goal không bị đổi");
    }

    @Test
    void changing_goal_adds_new_calorie_target() throws Exception {
        onboard();
        List<Document> before = user().getList("nutritionTargets", Document.class);
        DocumentContext after = patchMe("{\"goal\":\"build_muscle\"}", 200);
        assertEquals("build_muscle", after.read("$.profile.goal"));
        List<Document> targets = user().getList("nutritionTargets", Document.class);
        assertEquals(before.size() + 1, targets.size());
        assertTrue(targets.getLast().getInteger("kcal") > before.getLast().getInteger("kcal"), "tăng cơ ăn nhiều hơn giảm mỡ");

        patchMe("{\"goal\":\"build_muscle\"}", 200);                             // không đổi thì không thêm mốc
        assertEquals(targets.size(), user().getList("nutritionTargets", Document.class).size());
        assertEquals("VALIDATION_ERROR", patchMe("{\"goal\":\"fly\"}", 400).read("$.code"));
    }

    @Test
    void invalid_values_are_rejected() throws Exception {
        onboard();
        assertEquals("NOTHING_TO_UPDATE", patchMe("{}", 400).read("$.code"));
        assertEquals("VALIDATION_ERROR", patchMe("{\"displayName\":\"   \"}", 400).read("$.code"));
        assertEquals("VALIDATION_ERROR", patchMe("{\"coachStyle\":\"rude\"}", 400).read("$.code"));
        assertEquals("VALIDATION_ERROR",
            patchMe("{\"notifications\":{\"quietStart\":\"25:00\"}}", 400).read("$.code"));
        assertEquals("VALIDATION_ERROR",
            patchMe("{\"notifications\":{\"maxPerDay\":9}}", 400).read("$.code"));
        assertEquals("INVALID_TIMEZONE", patchMe("{\"timezone\":\"Mars/Base\"}", 400).read("$.code"));
        assertEquals("DUPLICATE_WEEKDAY", patchMe("""
            {"availability":[{"weekday":1,"slot":"noon"},{"weekday":1,"slot":"evening"}]}""", 400)
            .read("$.code"));
    }

    @Test
    void requires_onboarding() throws Exception {
        assertEquals("ONBOARDING_REQUIRED", patchMe("{\"coachStyle\":\"funny\"}", 404).read("$.code"));
    }

    @Test
    void achievements_listed_after_first_workout() throws Exception {
        String exerciseId = onboard().read("$.plan.sessions[0].items[0].exerciseId");
        Instant end = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        String workout = """
            {"clientId":"settings-%s","startedAt":"%s","endedAt":"%s","variant":"normal",
             "sets":[{"exerciseId":"%s","setIndex":1,"reps":10}]}"""
            .formatted(uid.substring(3, 15), end.minus(10, ChronoUnit.MINUTES), end, exerciseId);
        call(post("/workouts").header("Authorization", token)
            .contentType(MediaType.APPLICATION_JSON).content(workout), 200);
        DocumentContext me = call(get("/me").header("Authorization", token), 200);
        assertEquals("sessions_1", me.read("$.achievements[0].code"));
        assertTrue(me.<String>read("$.achievements[0].earnedAt").startsWith("20"));
    }

    @Test
    void changing_equipment_unlocks_exercises() throws Exception {
        onboard();                                  // ở nhà, không dụng cụ
        int before = call(get("/exercises").header("Authorization", token), 200).<Integer>read("$.length()");

        DocumentContext after = patchMe("""
            {"equipment":["dumbbell","resistance_band","dumbbell"]}""", 200);
        assertEquals("home", after.read("$.profile.location"), "không gửi location thì giữ");
        assertEquals(List.of("dumbbell", "resistance_band"), after.read("$.profile.equipment"));
        int withGear = call(get("/exercises").header("Authorization", token), 200).<Integer>read("$.length()");
        assertTrue(withGear > before, "có tạ đơn + dây kháng lực thì thêm bài: " + before + " -> " + withGear);

        assertEquals("gym", patchMe("{\"location\":\"gym\"}", 200).read("$.profile.location"));
        assertEquals(List.of(), patchMe("{\"equipment\":[]}", 200).read("$.profile.equipment"));

        assertEquals("VALIDATION_ERROR", patchMe("{\"equipment\":[\"barbell\"]}", 400).read("$.code"));
        assertEquals("VALIDATION_ERROR", patchMe("{\"location\":\"moon\"}", 400).read("$.code"));
    }
}
