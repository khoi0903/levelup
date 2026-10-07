package vn.levelup.engagement.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;
import vn.levelup.engagement.service.CoachTemplates;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.rules.SessionRules;


class SkipPlannerTest {

    private static final LocalDate MONDAY = LocalDate.of(2026, 9, 28);
    private static final LocalDate WEDNESDAY = MONDAY.plusDays(2);

    private static Exercise ex(String id, String muscle, String... contraindications) {
        return new Exercise(id, id, id, null, null, null, null, null, muscle, 1, "reps", null, List.of(),
            List.of(contraindications), null, true);
    }

    // id hex 24 ký tự, sắp theo thứ tự chữ
    private static final Exercise SQUAT = ex("a00000000000000000000001", "legs", "knee");
    private static final Exercise LUNGE = ex("a00000000000000000000002", "legs", "knee");
    private static final Exercise BRIDGE = ex("a00000000000000000000003", "legs");
    private static final Exercise PUSHUP = ex("a00000000000000000000004", "chest", "wrist");
    private static final Exercise WALL_PUSH = ex("a00000000000000000000005", "chest");
    private static final List<Exercise> ALL = List.of(SQUAT, LUNGE, BRIDGE, PUSHUP, WALL_PUSH);
    private static final Map<String, Exercise> CATALOG = ALL.stream()
        .collect(Collectors.toMap(Exercise::id, Function.identity()));

    private static TrainingPlan.Item item(Exercise e) {
        return new TrainingPlan.Item(new ObjectId(e.id()), 3, 12, null, 45);
    }

    private static TrainingPlan.Session session(LocalDate date, String status, Exercise... exercises) {
        return new TrainingPlan.Session(new ObjectId(), date.toString(), "18:30", "Buổi", 15, "normal", status,
            java.util.Arrays.stream(exercises).map(SkipPlannerTest::item).toList());
    }

    @Test
    void busy_shortens_next_session_and_moves_the_following_to_a_free_day() {
        TrainingPlan.Session past = session(MONDAY, "skipped", SQUAT);
        TrainingPlan.Session today = session(WEDNESDAY, "planned", SQUAT, PUSHUP, BRIDGE, LUNGE);
        TrainingPlan.Session thursday = session(WEDNESDAY.plusDays(1), "planned", BRIDGE);
        TrainingPlan.Session friday = session(WEDNESDAY.plusDays(2), "planned", BRIDGE);
        var out = SkipPlanner.plan("busy", List.of(past, today, thursday, friday), WEDNESDAY, MONDAY, past.id(),
            null, CATALOG, ALL);

        assertEquals("shortened", out.action());
        assertEquals(2, out.changed().size());
        TrainingPlan.Session shortened = out.changed().get(0);
        assertEquals(today.id(), shortened.id());
        assertEquals(10, shortened.durationMin());
        assertTrue(vn.levelup.training.rules.SessionRules.estimateSec(shortened.items()) <= 600);
        assertEquals("skip_busy", shortened.adjustedReason());
        TrainingPlan.Session moved = out.changed().get(1);
        assertEquals(thursday.id(), moved.id());
        assertEquals("2026-10-03", moved.scheduledDate());     // Thứ Sáu đã có buổi, Thứ Bảy trống
    }

    @Test
    void busy_without_remaining_sessions_does_nothing() {
        TrainingPlan.Session done = session(MONDAY, "completed", SQUAT);
        var out = SkipPlanner.plan("busy", List.of(done), WEDNESDAY, MONDAY, null, null, CATALOG, ALL);
        assertEquals("none", out.action());
        assertTrue(out.changed().isEmpty());
    }

    @Test
    void tired_makes_remaining_sessions_light() {
        TrainingPlan.Session past = session(MONDAY, "planned", SQUAT);
        TrainingPlan.Session next = session(WEDNESDAY, "planned", SQUAT);
        var out = SkipPlanner.plan("tired", List.of(past, next), WEDNESDAY, MONDAY, null, null, CATALOG, ALL);
        assertEquals("reduced_intensity", out.action());
        assertEquals(1, out.changed().size());
        assertEquals("light", out.changed().get(0).variant());
        assertEquals(2, out.changed().get(0).items().get(0).targetSets());
    }

    @Test
    void pain_replaces_contraindicated_exercises_with_safe_ones() {
        TrainingPlan.Session next = session(WEDNESDAY, "planned", SQUAT, PUSHUP);
        List<Exercise> safe = List.of(BRIDGE, PUSHUP, WALL_PUSH);       // đã bỏ bài chống chỉ định gối
        var out = SkipPlanner.plan("pain", List.of(next), WEDNESDAY, MONDAY, null, "knee", CATALOG, safe);
        assertEquals("swapped_exercises", out.action());
        TrainingPlan.Session s = out.changed().get(0);
        assertEquals("pain_knee", s.adjustedReason());
        assertEquals(List.of(BRIDGE.id(), PUSHUP.id()),
            s.items().stream().map(i -> i.exerciseId().toHexString()).toList());
    }

    @Test
    void pain_never_leaves_a_session_empty() {
        TrainingPlan.Session next = session(WEDNESDAY, "planned", SQUAT);
        var noLegs = SkipPlanner.plan("pain", List.of(next), WEDNESDAY, MONDAY, null, "knee", CATALOG,
            List.of(WALL_PUSH));
        assertEquals(List.of(WALL_PUSH.id()), noLegs.changed().get(0).items().stream()
            .map(i -> i.exerciseId().toHexString()).toList());

        var nothingSafe = SkipPlanner.plan("pain", List.of(next), WEDNESDAY, MONDAY, null, "knee", CATALOG,
            List.of());
        TrainingPlan.Session rest = nothingSafe.changed().get(0);
        assertEquals("rest", rest.status());
        assertFalse(rest.items().isEmpty());
    }

    @Test
    void bored_swaps_to_same_muscle() {
        TrainingPlan.Session next = session(WEDNESDAY, "planned", SQUAT, PUSHUP);
        var out = SkipPlanner.plan("bored", List.of(next), WEDNESDAY, MONDAY, null, null, CATALOG, ALL);
        assertEquals("swapped_exercises", out.action());
        assertEquals(List.of(LUNGE.id(), WALL_PUSH.id()), out.changed().get(0).items().stream()
            .map(i -> i.exerciseId().toHexString()).toList());
    }

    @Test
    void forgot_only_suggests_reminder() {
        TrainingPlan.Session next = session(WEDNESDAY, "planned", SQUAT);
        var out = SkipPlanner.plan("forgot", List.of(next), WEDNESDAY, MONDAY, null, null, CATALOG, ALL);
        assertEquals("changed_reminder", out.action());
        assertTrue(out.changed().isEmpty());
        assertEquals(60, out.suggestion().get("preWorkoutMinutes"));
    }

    @Test
    void templates_fill_placeholders() {
        assertEquals("Lan, chào bạn.", CoachTemplates.fill("{ten}, chào bạn.", Map.of("ten", "Lan")));
        assertEquals("vì sức khỏe", CoachTemplates.fill("vì {ly_do}", Map.of("ly_do", "sức khỏe")));
        assertEquals("Chào bạn", CoachTemplates.fill("Chào {ten} bạn", Map.of()).replace("  ", " "));
    }
}
