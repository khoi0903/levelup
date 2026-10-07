package vn.levelup.training.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;
import vn.levelup.training.model.TrainingPlan;


class RpeRulesTest {

    private static final ObjectId A = new ObjectId();
    private static final ObjectId B = new ObjectId();
    private static final List<TrainingPlan.Item> ITEMS = List.of(
        new TrainingPlan.Item(A, 2, 10, null, 45),
        new TrainingPlan.Item(B, 6, 12, null, 45));

    @Test
    void easy_adds_a_set_or_two_reps_when_at_max_sets() {
        var a = RpeRules.adjust(ITEMS, 4, null).orElseThrow();
        assertEquals("rpe_easy", a.reason());
        assertEquals(3, a.items().get(0).targetSets());
        assertEquals(10, a.items().get(0).targetReps());
        assertEquals(6, a.items().get(1).targetSets());
        assertEquals(14, a.items().get(1).targetReps());
    }

    @Test
    void moderate_keeps_plan() {
        assertTrue(RpeRules.adjust(ITEMS, 6, List.of()).isEmpty());
        assertTrue(RpeRules.adjust(ITEMS, 8, null).isEmpty());
        assertTrue(RpeRules.adjust(ITEMS, null, null).isEmpty());
    }

    @Test
    void hard_or_pain_removes_a_set_down_to_one() {
        var hard = RpeRules.adjust(ITEMS, 9, null).orElseThrow();
        assertEquals("rpe_hard", hard.reason());
        assertEquals(List.of(1, 5), hard.items().stream().map(TrainingPlan.Item::targetSets).toList());

        var pain = RpeRules.adjust(ITEMS, 5, List.of("knee")).orElseThrow();
        assertEquals("rpe_pain", pain.reason());

        List<TrainingPlan.Item> minimal = List.of(new TrainingPlan.Item(A, 1, 10, null, 45));
        assertTrue(RpeRules.adjust(minimal, 10, null).isEmpty());   // đã tối thiểu, không đổi gì
    }

    @Test
    void comeback_after_seven_days() {
        Instant now = Instant.parse("2026-10-03T12:00:00Z");
        assertTrue(RpeRules.isComeback(now.minus(7, ChronoUnit.DAYS), now));
        assertFalse(RpeRules.isComeback(now.minus(6, ChronoUnit.DAYS), now));
        assertFalse(RpeRules.isComeback(null, now));
    }
}
