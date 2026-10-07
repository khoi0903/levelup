package vn.levelup.training.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Map;

import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.NullSource;
import org.junit.jupiter.params.provider.ValueSource;
import vn.levelup.training.dto.PlanView;
import vn.levelup.training.model.TrainingPlan;


class CheckinAdjusterTest {

    private static TrainingPlan.Session session(Integer sets) {
        return new TrainingPlan.Session(new ObjectId(), "2026-10-03", "18:30", "Toàn thân", 15,
            "normal", "planned", List.of(
                new TrainingPlan.Item(new ObjectId(), sets, 10, null, 45),
                new TrainingPlan.Item(new ObjectId(), 2, null, 30, 60)));
    }

    @ParameterizedTest
    @NullSource
    @ValueSource(strings = {"lt6", "h6_7", "h7_8", "gt8"})
    void tired_reduces_every_item_and_preserves_other_fields(String sleep) {
        TrainingPlan.Session original = session(3);
        var result = CheckinAdjuster.adjust(original, "tired", sleep);
        assertTrue(result.adjusted());
        assertEquals("light", result.session().variant());
        assertEquals("checkin_tired", result.session().adjustedReason());
        assertEquals(List.of(2, 1), result.session().items().stream().map(TrainingPlan.Item::targetSets).toList());
        assertEquals(original.id(), result.session().id());
        assertEquals(original.scheduledDate(), result.session().scheduledDate());
        assertEquals(original.scheduledTime(), result.session().scheduledTime());
        assertEquals(original.title(), result.session().title());
        assertEquals(original.durationMin(), result.session().durationMin());
        assertEquals(original.status(), result.session().status());
        for (int i = 0; i < original.items().size(); i++) {
            var before = original.items().get(i);
            var after = result.session().items().get(i);
            assertEquals(before.exerciseId(), after.exerciseId());
            assertEquals(before.targetReps(), after.targetReps());
            assertEquals(before.targetDurationSec(), after.targetDurationSec());
            assertEquals(before.restSec(), after.restSec());
        }
        assertEquals(3, original.items().get(0).targetSets());
        assertEquals("normal", original.variant());
        assertNull(original.adjustedReason());
    }

    @ParameterizedTest
    @ValueSource(strings = {"normal", "energized"})
    void short_sleep_takes_priority_over_energy(String energy) {
        var result = CheckinAdjuster.adjust(session(3), energy, "lt6");
        assertTrue(result.adjusted());
        assertEquals("light", result.session().variant());
        assertEquals("checkin_tired", result.session().adjustedReason());
        assertEquals(2, result.session().items().get(0).targetSets());
    }

    @ParameterizedTest
    @NullSource
    @ValueSource(strings = {"h6_7", "h7_8", "gt8"})
    void energized_keeps_all_sets(String sleep) {
        TrainingPlan.Session original = session(3);
        var result = CheckinAdjuster.adjust(original, "energized", sleep);
        assertTrue(result.adjusted());
        assertEquals("advanced", result.session().variant());
        assertEquals("checkin_energized", result.session().adjustedReason());
        assertEquals(original.items(), result.session().items());
    }

    @ParameterizedTest
    @NullSource
    @ValueSource(strings = {"h6_7", "h7_8", "gt8"})
    void normal_does_not_change_session(String sleep) {
        TrainingPlan.Session original = session(3);
        var result = CheckinAdjuster.adjust(original, "normal", sleep);
        assertFalse(result.adjusted());
        assertSame(original, result.session());
    }

    @Test
    void one_set_never_becomes_zero() {
        var result = CheckinAdjuster.adjust(session(1), "tired", null);
        assertEquals(1, result.session().items().get(0).targetSets());
    }

    @Test
    void optional_sets_remain_absent() {
        var result = CheckinAdjuster.adjust(session(null), "tired", null);
        assertNull(result.session().items().get(0).targetSets());
    }

    @Test
    void plan_view_includes_reason_and_vietnamese_exercise_name() {
        TrainingPlan.Session adjusted = CheckinAdjuster.adjust(session(3), "tired", null).session();
        String exerciseId = adjusted.items().get(0).exerciseId().toHexString();
        TrainingPlan plan = new TrainingPlan(new ObjectId().toHexString(), new ObjectId(), "2026-09-28",
            "active", 3, "rule", null, List.of(adjusted), null);
        var view = PlanView.of(plan, Map.of(exerciseId, "Squat cơ bản")).sessions().get(0);
        assertEquals("checkin_tired", view.adjustedReason());
        assertEquals("Squat cơ bản", view.items().get(0).nameVi());
    }
}
