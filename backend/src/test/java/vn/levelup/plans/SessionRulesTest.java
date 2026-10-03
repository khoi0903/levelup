package vn.levelup.plans;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.IntStream;

import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;

class SessionRulesTest {

    private static TrainingPlan.Item reps(int sets, int reps, int rest) {
        return new TrainingPlan.Item(new ObjectId(), sets, reps, null, rest);
    }

    @Test
    void estimate_counts_sets_work_and_rest() {
        assertEquals(2 * (30 + 45), SessionRules.estimateSec(reps(2, 10, 45)));
        assertEquals(3 * (40 + 20), SessionRules.estimateSec(new TrainingPlan.Item(new ObjectId(), 3, null, 40, 20)));
    }

    @Test
    void quick5_fits_five_minutes_and_keeps_at_least_one_item() {
        List<TrainingPlan.Item> items = IntStream.range(0, 8).mapToObj(i -> reps(3, 12, 60)).toList();
        List<TrainingPlan.Item> quick = SessionRules.quick5(items);
        assertTrue(SessionRules.estimateSec(quick) <= SessionRules.QUICK5_SEC);
        assertTrue(quick.size() >= 1 && quick.size() < items.size());
        assertTrue(quick.stream().allMatch(i -> i.targetSets() == 1 && i.restSec() == 20));
        assertEquals(items.get(0).exerciseId(), quick.get(0).exerciseId());

        TrainingPlan.Item huge = new TrainingPlan.Item(new ObjectId(), 5, null, 600, 60);
        assertEquals(1, SessionRules.quick5(List.of(huge)).size());
    }

    @Test
    void fit_reduces_sets_before_dropping_items() {
        List<TrainingPlan.Item> items = List.of(reps(3, 10, 30), reps(3, 10, 30));   // 360 giây
        List<TrainingPlan.Item> fitted = SessionRules.fit(items, 300, null);
        assertEquals(2, fitted.size());
        assertTrue(SessionRules.estimateSec(fitted) <= 300);
    }

    @Test
    void reschedule_must_stay_in_week_and_not_in_past() {
        LocalDate monday = LocalDate.of(2026, 9, 28);
        LocalDate today = LocalDate.of(2026, 10, 1);
        assertNull(SessionRules.rescheduleError(monday, today, today));
        assertNull(SessionRules.rescheduleError(monday, today, LocalDate.of(2026, 10, 4)));
        assertEquals("DATE_IN_PAST", SessionRules.rescheduleError(monday, today, LocalDate.of(2026, 9, 30)));
        assertEquals("DATE_OUTSIDE_WEEK", SessionRules.rescheduleError(monday, today, LocalDate.of(2026, 10, 5)));
    }
}
