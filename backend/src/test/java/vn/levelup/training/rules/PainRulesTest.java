package vn.levelup.training.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;


class PainRulesTest {

    private static final LocalDate TODAY = LocalDate.of(2026, 10, 15);

    private static PainRules.Watch reported(int daysAgo) {
        return new PainRules.Watch("knee", TODAY.minusDays(daysAgo), null, null);
    }

    @Test
    void only_sharp_pain_starts_a_watch() {
        assertTrue(PainRules.startsWatch("sharp", List.of("knee")));
        assertFalse(PainRules.startsWatch("soreness", List.of("knee")));
        assertFalse(PainRules.startsWatch(null, List.of("knee")));
        assertFalse(PainRules.startsWatch("sharp", List.of()));
        assertFalse(PainRules.startsWatch("sharp", null));
    }

    @Test
    void soreness_does_not_reduce_next_session_but_old_apps_still_do() {
        assertEquals(List.of(), PainRules.areasForAdjust("soreness", List.of("knee")));
        assertEquals(List.of("knee"), PainRules.areasForAdjust("sharp", List.of("knee")));
        assertEquals(List.of("knee"), PainRules.areasForAdjust(null, List.of("knee")));
    }

    @Test
    void due_from_the_next_day_once_per_day() {
        assertFalse(PainRules.isDue(reported(0), TODAY));
        assertTrue(PainRules.isDue(reported(1), TODAY));
        assertFalse(PainRules.isDue(new PainRules.Watch("knee", TODAY.minusDays(2), "same", TODAY), TODAY));
        assertTrue(PainRules.isDue(new PainRules.Watch("knee", TODAY.minusDays(2), "same", TODAY.minusDays(1)),
            TODAY));
    }

    @Test
    void answers_map_to_status() {
        assertEquals(PainRules.Status.RESOLVED, PainRules.answer(reported(1), "gone", TODAY, "đầu gối").status());
        assertEquals(PainRules.Status.MONITORING, PainRules.answer(reported(1), "better", TODAY, "đầu gối").status());
        assertEquals(PainRules.Status.MONITORING, PainRules.answer(reported(2), "same", TODAY, "đầu gối").status());
        assertEquals(PainRules.Status.INJURY, PainRules.answer(reported(1), "worse", TODAY, "đầu gối").status());
    }

    @Test
    void still_hurting_after_three_days_becomes_injury_and_mentions_doctor() {
        PainRules.Decision d = PainRules.answer(reported(PainRules.MAX_WATCH_DAYS), "same", TODAY, "đầu gối");
        assertEquals(PainRules.Status.INJURY, d.status());
        assertTrue(d.message().contains("đi khám"));
        assertTrue(d.message().contains("đầu gối"));
        // Đỡ hơn thì không chuyển thành chấn thương dù đã lâu
        assertEquals(PainRules.Status.MONITORING, PainRules.answer(reported(5), "better", TODAY, null).status());
    }
}
