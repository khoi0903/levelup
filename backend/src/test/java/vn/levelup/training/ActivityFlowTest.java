package vn.levelup.training;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.time.Instant;
import java.util.Date;
import java.util.List;

import org.bson.Document;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;

import com.jayway.jsonpath.DocumentContext;
import vn.levelup.FlowTestBase;


/** POST /activity/today (Health Connect) và số liệu trong GET /nutrition/today. */
@SpringBootTest
@ActiveProfiles("dev")
class ActivityFlowTest extends FlowTestBase {

    private DocumentContext send(String date, int steps, int kcal, int expected) throws Exception {
        return call(post("/activity/today").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"localDate\":\"%s\",\"steps\":%d,\"activeKcal\":%d}".formatted(date, steps, kcal)), expected);
    }

    @Test
    void stores_todays_activity_and_never_decreases() throws Exception {
        onboard();
        String today = call(get("/me").header("Authorization", token), 200).read("$.localDate");

        DocumentContext r = send(today, 5200, 180, 200);
        assertTrue(r.<Boolean>read("$.stored"));
        assertEquals(5200, r.<Integer>read("$.steps"));

        // Gửi lại số nhỏ hơn (đọc trễ) không làm giảm
        r = send(today, 3000, 90, 200);
        assertEquals(5200, r.<Integer>read("$.steps"));
        assertEquals(180, r.<Integer>read("$.activeKcal"));

        DocumentContext nutrition = call(get("/nutrition/today").header("Authorization", token), 200);
        assertEquals(5200, nutrition.<Integer>read("$.steps"));
        assertEquals(180, nutrition.<Integer>read("$.activeKcal"));
        assertEquals(180, nutrition.<Integer>read("$.totalBurnedKcal"));
    }

    @Test
    void ignores_other_days_and_bad_values() throws Exception {
        onboard();
        assertFalse(send("2000-01-01", 1000, 50, 200).<Boolean>read("$.stored"));
        assertEquals(0, call(get("/nutrition/today").header("Authorization", token), 200).<Integer>read("$.steps"));
        send("2026-10-17", -1, 50, 400);
        send("2026-10-17", 100, 99999, 400);
    }

    @Test
    void adds_workout_and_activity_without_double_counting_and_keeps_history() throws Exception {
        onboard();
        String today = call(get("/me").header("Authorization", token), 200).read("$.localDate");
        Instant start = Instant.now().minusSeconds(3600);
        mongo.insert(new Document("userId", userId()).append("localDate", today).append("startedAt", Date.from(start))
            .append("endedAt", Date.from(start.plusSeconds(1800))).append("durationSec", 1800).append("kcalBurned", 150)
            .append("variant", "normal").append("sets", List.of()), "workout_logs");

        // App cũ (không gửi phần trùng): lấy số lớn hơn như trước
        send(today, 5200, 180, 200);
        assertEquals(180, call(get("/nutrition/today").header("Authorization", token), 200)
            .<Integer>read("$.totalBurnedKcal"));

        // App lấy giờ buổi tập, đọc Health Connect trong khoảng đó (40 kcal) rồi gửi: 150 + (180 − 40)
        DocumentContext t = call(get("/activity/today").header("Authorization", token), 200);
        assertEquals(5200, t.<Integer>read("$.steps"));
        assertEquals(1, t.<List<Object>>read("$.workoutWindows").size());
        call(post("/activity/today").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"localDate\":\"%s\",\"steps\":5200,\"activeKcal\":180,\"activeKcalInWorkouts\":40}"
                .formatted(today)), 200);
        assertEquals(290, call(get("/nutrition/today").header("Authorization", token), 200)
            .<Integer>read("$.totalBurnedKcal"));

        DocumentContext h = call(get("/activity/history?days=7").header("Authorization", token), 200);
        assertEquals(7, h.<List<Object>>read("$.days").size());
        assertEquals(today, h.read("$.days[6].localDate"));
        assertEquals(5200, h.<Integer>read("$.days[6].steps"));
        assertEquals(150, h.<Integer>read("$.days[6].workoutKcal"));
        assertEquals(290, h.<Integer>read("$.days[6].totalBurnedKcal"));
        assertEquals(0, h.<Integer>read("$.days[0].steps"));
        assertEquals(90, call(get("/activity/history?days=500").header("Authorization", token), 200)
            .<List<Object>>read("$.days").size());
    }
}
