package vn.levelup.engagement;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.time.Instant;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;

import com.jayway.jsonpath.DocumentContext;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.FlowTestBase;


/** Lịch sử streak của người mới chỉ có tuần này; chi tiết tuần trả đủ 7 ngày với buổi đã tập. */
@SpringBootTest
@ActiveProfiles("dev")
class StreakWeekFlowTest extends FlowTestBase {

    @Test
    void new_user_history_and_week_detail() throws Exception {
        String exerciseId = onboard().read("$.plan.sessions[0].items[0].exerciseId");

        DocumentContext streak = call(get("/streak").header("Authorization", token), 200);
        assertEquals(1, streak.<Integer>read("$.weeks.length()"), "không còn 7 tuần trống 0/0 buổi");

        // Một buổi tập thêm hôm nay (không gắn lịch)
        Instant end = Instant.now().truncatedTo(ChronoUnit.SECONDS);
        call(post("/workouts").header("Authorization", token).contentType(MediaType.APPLICATION_JSON).content("""
            {"clientId":"week-%s","startedAt":"%s","endedAt":"%s","variant":"normal",
             "sets":[{"exerciseId":"%s","setIndex":1,"reps":10}]}"""
            .formatted(uid.substring(3, 15), end.minus(10, ChronoUnit.MINUTES), end, exerciseId)), 200);

        String today = LocalDate.now(LocalDates.DEFAULT_ZONE).toString();
        DocumentContext week = call(get("/streak/weeks/" + today).header("Authorization", token), 200);
        assertEquals(LocalDates.weekStart(LocalDate.parse(today)).toString(), week.read("$.weekStart"));
        assertEquals(7, week.<Integer>read("$.days.length()"));
        assertEquals(1, week.<Integer>read("$.days[0].weekday"));
        List<Map<String, Object>> todayDays = week.read("$.days[?(@.date == '" + today + "')]");
        assertEquals(1, todayDays.size());
        List<Map<String, Object>> workouts = week.read("$.days[?(@.date == '" + today + "')].workouts[*]");
        assertEquals(1, workouts.size());
        assertTrue((Boolean) workouts.getFirst().get("countsForStreak"));

        assertEquals("INVALID_DATE", call(get("/streak/weeks/hom-nay").header("Authorization", token), 400)
            .read("$.code"));
    }
}
