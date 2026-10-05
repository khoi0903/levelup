package vn.levelup.workouts;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Optional;
import java.util.Set;

import org.junit.jupiter.api.Test;

class WorkoutRulesTest {

    private static final String SQUAT = "a".repeat(24);
    private static final String PLANK = "b".repeat(24);

    private static WorkoutRequest.SetLog set(String ex, int idx, Integer reps, Double kg, Integer sec) {
        return new WorkoutRequest.SetLog(ex, idx, reps, kg, sec, null, null, null, null, null, null);
    }

    @Test
    void five_minutes_counts_for_streak() {
        assertFalse(WorkoutRules.countsForStreak(299));
        assertTrue(WorkoutRules.countsForStreak(300));
    }

    @Test
    void bests_pick_highest_value_per_exercise_and_metric() {
        List<WorkoutRules.Best> bests = WorkoutRules.bests(List.of(
            set(SQUAT, 1, 12, null, null),
            set(SQUAT, 2, 15, 10.0, null),
            set(SQUAT, 3, 15, 12.5, null),
            set(PLANK, 1, null, null, 45)));
        assertTrue(bests.contains(new WorkoutRules.Best(SQUAT, "max_reps", 15, 2)));   // hòa giữ hiệp đầu
        assertTrue(bests.contains(new WorkoutRules.Best(SQUAT, "max_weight", 12.5, 3)));
        assertTrue(bests.contains(new WorkoutRules.Best(PLANK, "max_duration", 45, 1)));
        assertEquals(3, bests.size());
    }

    @Test
    void first_time_is_not_reported_as_record() {
        assertFalse(WorkoutRules.isNewRecord(null, 20));
        assertFalse(WorkoutRules.isNewRecord(20.0, 20));
        assertTrue(WorkoutRules.isNewRecord(20.0, 21));
    }

    @Test
    void session_milestones_only_once() {
        assertEquals(Optional.of("sessions_1"), WorkoutRules.sessionMilestone(1, Set.of()));
        assertEquals(Optional.empty(), WorkoutRules.sessionMilestone(1, Set.of("sessions_1")));
        assertEquals(Optional.empty(), WorkoutRules.sessionMilestone(9, Set.of()));
        assertEquals(Optional.of("sessions_10"), WorkoutRules.sessionMilestone(10, Set.of("sessions_1")));
    }

    @Test
    void week_becomes_achieved_only_from_in_progress() {
        assertEquals("in_progress", WorkoutRules.weekStatus("in_progress", 2, 3));
        assertEquals("achieved", WorkoutRules.weekStatus("in_progress", 3, 3));
        assertEquals("achieved", WorkoutRules.weekStatus("achieved", 4, 3));
        assertEquals("missed", WorkoutRules.weekStatus("missed", 5, 3));
    }

    @Test
    void kcal_burned_met_weighted_by_sets() {
        // 20 phút, 70 kg: 2 hiệp squat (MET 5) + 2 hiệp plank (MET 3) → MET trung bình 4 → 4 × 70 × 1/3 ≈ 93
        List<WorkoutRequest.SetLog> sets = List.of(set(SQUAT, 1, 10, null, null), set(SQUAT, 2, 10, null, null),
            set(PLANK, 1, null, null, 30), set(PLANK, 2, null, null, 30));
        assertEquals(93, WorkoutRules.kcalBurned(sets, java.util.Map.of(SQUAT, 5.0, PLANK, 3.0), 1200, 70));
        // Bài chưa có MET dùng mặc định 4
        assertEquals(93, WorkoutRules.kcalBurned(sets, java.util.Map.of(), 1200, 70));
        assertEquals(0, WorkoutRules.kcalBurned(List.of(), java.util.Map.of(), 1200, 70));
        assertEquals(0, WorkoutRules.kcalBurned(sets, java.util.Map.of(), 0, 70));
    }
}
