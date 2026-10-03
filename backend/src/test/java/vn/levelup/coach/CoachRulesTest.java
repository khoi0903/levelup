package vn.levelup.coach;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;

import vn.levelup.coach.CoachRules.Action;
import vn.levelup.coach.CoachRules.Fact;
import vn.levelup.coach.CoachRules.Intent;
import vn.levelup.coach.CoachRules.Proposal;
import vn.levelup.coach.CoachRules.UserCtx;
import vn.levelup.exercises.Exercise;
import vn.levelup.plans.TrainingPlan;

class CoachRulesTest {

    // id 24 ký tự hex cố định cho dễ đọc
    static final String PUSHUP = "a00000000000000000000001";
    static final String PLANK = "a00000000000000000000002";
    static final String SQUAT = "a00000000000000000000003";
    static final String WALL_PUSHUP = "a00000000000000000000004";
    static final String GOBLET = "a00000000000000000000005";
    static final String BRIDGE = "a00000000000000000000006";
    static final String OLD = "a00000000000000000000007";

    static Exercise ex(String id, String muscle, String tracking, int difficulty, List<String> equipment,
                       List<String> contra, boolean active) {
        return new Exercise(id, id, "Bài " + id.substring(23), null, null, null, null, null, muscle, difficulty,
            tracking, 4.0, equipment, contra, null, active);
    }

    static final List<Exercise> ALL = List.of(
        ex(PUSHUP, "chest", "reps", 2, List.of(), List.of("wrist", "shoulder"), true),
        ex(PLANK, "core", "duration", 1, List.of("mat"), List.of("shoulder", "lower_back"), true),
        ex(SQUAT, "legs", "reps", 1, List.of(), List.of("knee"), true),
        ex(WALL_PUSHUP, "chest", "reps", 1, List.of(), List.of(), true),
        ex(GOBLET, "legs", "reps", 2, List.of("dumbbell"), List.of("knee"), true),
        ex(BRIDGE, "glutes", "reps", 1, List.of(), List.of("lower_back"), true),
        ex(OLD, "chest", "reps", 1, List.of(), List.of(), false));

    static Map<String, Exercise> byId() {
        Map<String, Exercise> m = new LinkedHashMap<>();
        ALL.forEach(e -> m.put(e.id(), e));
        return m;
    }

    static TrainingPlan.Item item(String id, int sets) {
        return new TrainingPlan.Item(new ObjectId(id), sets, 10, null, 45);
    }

    static final ObjectId SESSION = new ObjectId("b00000000000000000000001");
    static final ObjectId DONE = new ObjectId("b00000000000000000000002");

    static TrainingPlan plan() {
        TrainingPlan.Session s = new TrainingPlan.Session(SESSION, "2026-10-05", "18:30", "Toàn thân", 15, "normal",
            "planned", List.of(item(PUSHUP, 2), item(SQUAT, 2), item(PLANK, 2)));
        TrainingPlan.Session done = new TrainingPlan.Session(DONE, "2026-10-01", "18:30", "Cardio", 15, "normal",
            "completed", List.of(item(SQUAT, 2)));
        return new TrainingPlan("c00000000000000000000001", new ObjectId(), "2026-09-28", "active", 2, "rule", null,
            List.of(done, s), Instant.now());
    }

    static UserCtx user(Set<String> injuries) {
        return new UserCtx("Minh", "supportive", "home", Set.of(), injuries);
    }

    // ---------------------------------------------------------------- JSON từ AI

    @Test
    void docJsonHopLeKemCodeFence() {
        String raw = """
            ```json
            {"reply":"Đổi plank nhé","action":{"type":"adjust_session","sessionId":"%s","change":"swap_exercise",
             "fromExerciseId":"%s","toExerciseId":"%s","reason":"đau vai"},
             "memory":["Thích tập buổi tối","  ", "x"], "injury":{"bodyArea":"shoulder","note":"đau vai phải"}}
            ```""".formatted(SESSION.toHexString(), PLANK, BRIDGE);
        Proposal p = CoachRules.parseAi(raw).orElseThrow();
        assertEquals("Đổi plank nhé", p.reply());
        assertEquals("swap_exercise", p.action().change());
        assertEquals(BRIDGE, p.action().toExerciseId());
        assertEquals(List.of("Thích tập buổi tối"), p.memory());
        assertEquals("shoulder", p.injury().bodyArea());
    }

    @Test
    void jsonSaiCauTrucThiRong() {
        assertTrue(CoachRules.parseAi(null).isEmpty());
        assertTrue(CoachRules.parseAi("Xin chào").isEmpty());
        assertTrue(CoachRules.parseAi("{\"reply\":\"\"}").isEmpty());
        assertTrue(CoachRules.parseAi("{\"reply\":\"ok\",\"action\":{\"type\":\"delete_plan\"}}").isEmpty());
        assertTrue(CoachRules.parseAi("{\"reply\":\"ok\",\"action\":{\"type\":\"adjust_session\","
            + "\"sessionId\":\"abc\",\"change\":\"light\"}}").isEmpty());
        assertTrue(CoachRules.parseAi("{\"reply\":\"ok\",\"injury\":{\"bodyArea\":\"tim\"}}").isEmpty());
        assertTrue(CoachRules.parseAi("{\"reply\":\"ok\",\"memory\":\"không phải mảng\"}").isEmpty());
        // swap thiếu bài đích
        assertTrue(CoachRules.parseAi("{\"reply\":\"ok\",\"action\":{\"type\":\"adjust_session\",\"sessionId\":\""
            + SESSION.toHexString() + "\",\"change\":\"swap_exercise\",\"fromExerciseId\":\"" + PLANK + "\"}}").isEmpty());
        assertTrue(CoachRules.parseAi("{\"reply\":\"Chỉ trả lời\"}").isPresent());
    }

    // ---------------------------------------------------------------- Luật từ khóa

    @Test
    void nhanDienYDinhVaVungDau() {
        assertEquals(Intent.PAIN, CoachRules.intent("hôm nay đau vai"));
        assertEquals("shoulder", CoachRules.bodyArea("hôm nay đau vai"));
        assertEquals("lower_back", CoachRules.bodyArea("Đau lưng quá"));
        assertEquals(Intent.PAIN, CoachRules.intent("gối hơi khó chịu"));
        assertEquals("knee", CoachRules.bodyArea("gối hơi khó chịu"));
        assertEquals("wrist", CoachRules.bodyArea("đau cổ tay"));
        assertEquals("neck", CoachRules.bodyArea("đau cổ"));
        assertEquals("other", CoachRules.bodyArea("đau quá"));
        assertEquals(Intent.TIRED, CoachRules.intent("Mình mệt quá"));
        assertEquals(Intent.BUSY, CoachRules.intent("hôm nay bận lắm"));
        assertEquals(Intent.BUSY, CoachRules.intent("không có thời gian"));
        assertEquals(Intent.SICK, CoachRules.intent("mình bị ốm"));
        assertEquals(Intent.OTHER, CoachRules.intent("chào coach"));
        // "vài" không phải "vai"
        assertEquals(Intent.OTHER, CoachRules.intent("tập vài bài"));
    }

    @Test
    void dauVaiDeXuatChanThuongVaDoiBaiAnToan() {
        TrainingPlan.Session next = plan().sessions().get(1);
        Proposal p = CoachRules.fallback("hôm nay đau vai", user(Set.of()), next, ALL);
        assertEquals("shoulder", p.injury().bodyArea());
        assertEquals("swap_exercise", p.action().change());
        assertEquals(PUSHUP, p.action().fromExerciseId());
        assertEquals(WALL_PUSHUP, p.action().toExerciseId());          // cùng nhóm cơ, an toàn với vai
        assertTrue(p.reply().contains("vai"));
        assertTrue(p.reply().contains("Minh"));
    }

    @Test
    void metBanOmVaCauKhac() {
        TrainingPlan.Session next = plan().sessions().get(1);
        assertEquals("light", CoachRules.fallback("mệt quá", user(Set.of()), next, ALL).action().change());
        assertEquals("quick5", CoachRules.fallback("bận lắm", user(Set.of()), next, ALL).action().change());
        assertEquals("rest", CoachRules.fallback("bị sốt", user(Set.of()), next, ALL).action().change());
        Proposal other = CoachRules.fallback("chào coach", user(Set.of()), next, ALL);
        assertNull(other.action());
        assertNull(other.injury());
        assertFalse(other.reply().isBlank());
        // Không có buổi sắp tới: không có thẻ đổi buổi
        assertNull(CoachRules.fallback("mệt quá", user(Set.of()), null, ALL).action());
    }

    // ---------------------------------------------------------------- Kiểm tra thẻ hành động

    private static Optional<String> validate(Action a, Set<String> injuries) {
        return CoachRules.validateAction(a, plan(), byId(), "home", Set.of(), injuries);
    }

    private static Action swap(String sessionId, String from, String to) {
        return new Action("adjust_session", sessionId, "swap_exercise", from, to, "lý do");
    }

    @Test
    void kiemTraThe() {
        String s = SESSION.toHexString();
        assertTrue(validate(swap(s, PUSHUP, WALL_PUSHUP), Set.of()).isEmpty());
        assertTrue(validate(new Action("adjust_session", s, "light", null, null, "mệt"), Set.of()).isEmpty());
        assertEquals("SESSION_NOT_FOUND", validate(swap("b0000000000000000000000f", PUSHUP, WALL_PUSHUP), Set.of()).get());
        assertEquals("SESSION_NOT_PLANNED",
            validate(new Action("adjust_session", DONE.toHexString(), "light", null, null, "x"), Set.of()).get());
        assertEquals("EXERCISE_NOT_IN_SESSION", validate(swap(s, BRIDGE, WALL_PUSHUP), Set.of()).get());
        assertEquals("UNKNOWN_EXERCISE", validate(swap(s, PUSHUP, "f00000000000000000000000"), Set.of()).get());
        assertEquals("UNKNOWN_EXERCISE", validate(swap(s, PUSHUP, OLD), Set.of()).get());          // ngừng dùng
        assertEquals("EXERCISE_UNSAFE", validate(swap(s, SQUAT, GOBLET), Set.of()).get());          // thiếu tạ
        assertEquals("EXERCISE_UNSAFE", validate(swap(s, PUSHUP, BRIDGE), Set.of("lower_back")).get());
        assertEquals("SAME_EXERCISE", validate(swap(s, PUSHUP, PUSHUP), Set.of()).get());
        assertEquals("NO_ACTIVE_PLAN", CoachRules.validateAction(swap(s, PUSHUP, WALL_PUSHUP), null, byId(),
            "home", Set.of(), Set.of()).get());
    }

    @Test
    void apDungThayDoiVaThayBaiKhongAnToan() {
        TrainingPlan.Session s = plan().sessions().get(1);
        List<Exercise> safe = SafeSessions.safeList(ALL, "home", Set.of(), Set.of("shoulder"));
        TrainingPlan.Session light = SafeSessions.applyChange(s, "light", null, null, "pain_shoulder", byId(), safe);
        assertEquals("light", light.variant());
        assertEquals("pain_shoulder", light.adjustedReason());
        List<String> ids = light.items().stream().map(i -> i.exerciseId().toHexString()).toList();
        assertFalse(ids.contains(PUSHUP));
        assertFalse(ids.contains(PLANK));
        assertTrue(light.items().stream().allMatch(i -> i.targetSets() == 1));
        assertEquals(ids.size(), Set.copyOf(ids).size());                  // không trùng bài

        TrainingPlan.Session quick = SafeSessions.applyChange(s, "quick5", null, null, "coach_quick5", byId(),
            SafeSessions.safeList(ALL, "home", Set.of(), Set.of()));
        assertEquals(5, quick.durationMin());
        assertEquals("quick5", quick.variant());

        TrainingPlan.Session rest = SafeSessions.applyChange(s, "rest", null, null, "coach_rest", byId(), safe);
        assertEquals("rest", rest.status());
    }

    // ---------------------------------------------------------------- Trí nhớ

    @Test
    void gopTriNhoChongTrungVaGioiHan() {
        Instant t0 = Instant.parse("2026-10-01T00:00:00Z");
        List<Fact> existing = new ArrayList<>();
        for (int i = 0; i < 20; i++) {
            existing.add(Fact.of("Sự thật số " + i, t0));
        }
        Instant t1 = t0.plusSeconds(60);
        List<Fact> merged = CoachRules.mergeMemory(existing,
            List.of(Fact.of("SU THAT SO 3", t1), Fact.of("Thích tập buổi tối", t1)));
        assertEquals(20, merged.size());
        assertEquals("Thích tập buổi tối", merged.get(19).value());
        assertEquals("SU THAT SO 3", merged.get(18).value());               // trùng key: thay và đưa xuống cuối
        assertEquals("Sự thật số 1", merged.get(0).value());                // mẩu cũ nhất bị bỏ
        assertEquals(1, merged.stream().filter(f -> f.key().equals("su that so 3")).count());

        Fact injury = CoachRules.injuryFact(new CoachRules.Injury("shoulder", null), LocalDate.of(2026, 10, 3), t1);
        assertEquals("injury_shoulder", injury.key());
        assertEquals("Đau vai (báo ngày 03/10)", injury.value());
        assertNotNull(CoachRules.normalizeKey("Đau vai phải"));
        assertEquals("dau vai phai", CoachRules.normalizeKey("Đau vai phải!"));
    }
}
