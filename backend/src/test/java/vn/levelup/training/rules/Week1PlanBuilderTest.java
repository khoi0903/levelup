package vn.levelup.training.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;


class Week1PlanBuilderTest {

    private static Exercise ex(String muscle, int difficulty, String tracking) {
        return new Exercise(new ObjectId().toHexString(), muscle + difficulty, "Bài " + muscle, null, null, null,
            null, null, muscle, difficulty, tracking, 4.0, List.of(), List.of(), null, true);
    }

    private static final List<Exercise> LIBRARY = List.of(
        ex("legs", 1, "reps"), ex("legs", 2, "reps_weight"), ex("chest", 2, "reps"),
        ex("core", 1, "duration"), ex("cardio", 1, "duration"), ex("glutes", 1, "reps"),
        ex("back", 3, "reps"), ex("shoulders", 2, "reps_weight"), ex("full_body", 2, "reps"));

    private static Map<Integer, String> days(int... weekdays) {
        Map<Integer, String> m = new LinkedHashMap<>();
        for (int d : weekdays) {
            m.put(d, "evening");
        }
        return m;
    }

    @Test
    void ba_buoi_vao_ngay_ranh_tu_hom_nay() {
        LocalDate monday = LocalDate.parse("2026-10-05");
        Week1PlanBuilder.Draft d = Week1PlanBuilder.build(monday, days(1, 3, 5), 15, LIBRARY);
        assertEquals(LocalDate.parse("2026-10-05"), d.weekStart());
        assertEquals(List.of("2026-10-05", "2026-10-07", "2026-10-09"),
            d.sessions().stream().map(TrainingPlan.Session::scheduledDate).toList());
        assertEquals("18:30", d.sessions().get(0).scheduledTime());
    }

    @Test
    void bo_qua_ngay_da_qua_trong_tuan() {
        LocalDate thursday = LocalDate.parse("2026-10-08");
        Week1PlanBuilder.Draft d = Week1PlanBuilder.build(thursday, days(1, 3, 5), 15, LIBRARY);
        assertEquals(List.of("2026-10-09"), d.sessions().stream().map(TrainingPlan.Session::scheduledDate).toList());
    }

    @Test
    void het_ngay_ranh_trong_tuan_thi_lap_cho_tuan_sau() {
        LocalDate saturday = LocalDate.parse("2026-10-10");
        Week1PlanBuilder.Draft d = Week1PlanBuilder.build(saturday, days(1, 3, 5), 15, LIBRARY);
        assertEquals(LocalDate.parse("2026-10-12"), d.weekStart());
        assertEquals(3, d.sessions().size());
    }

    @Test
    void ranh_nhieu_ngay_van_chi_3_buoi_trai_deu() {
        LocalDate monday = LocalDate.parse("2026-10-05");
        Week1PlanBuilder.Draft d = Week1PlanBuilder.build(monday, days(1, 2, 3, 4, 5, 6, 7), 30, LIBRARY);
        assertEquals(List.of("2026-10-05", "2026-10-08", "2026-10-11"),
            d.sessions().stream().map(TrainingPlan.Session::scheduledDate).toList());
    }

    @Test
    void tuan_dau_toi_da_15_phut_va_bai_tinh_gio_dung_giay() {
        Week1PlanBuilder.Draft d = Week1PlanBuilder.build(LocalDate.parse("2026-10-05"), days(1), 45, LIBRARY);
        TrainingPlan.Session s = d.sessions().get(0);
        assertEquals(15, s.durationMin());
        assertTrue(s.items().size() >= 4 && s.items().size() <= 6);
        assertTrue(s.items().stream().allMatch(i -> (i.targetReps() == null) != (i.targetDurationSec() == null)));
    }

    @Test
    void khong_co_bai_tap_van_tao_duoc_lich() {
        Week1PlanBuilder.Draft d = Week1PlanBuilder.build(LocalDate.parse("2026-10-05"), days(1, 3), 10, List.of());
        assertEquals(2, d.sessions().size());
        assertTrue(d.sessions().get(0).items().isEmpty());
    }

    @Test
    void khong_chon_ngay_rong_thi_dung_thu_2_4_6() {
        Week1PlanBuilder.Draft d = Week1PlanBuilder.build(LocalDate.parse("2026-10-05"), Map.of(), 10, LIBRARY);
        assertEquals(List.of("2026-10-05", "2026-10-07", "2026-10-09"),
            d.sessions().stream().map(TrainingPlan.Session::scheduledDate).toList());
    }

    @Test
    void khong_xep_bai_gian_co_vao_ke_hoach_du_de_nhat() {
        List<Exercise> library = new java.util.ArrayList<>(LIBRARY);
        for (int i = 0; i < 6; i++) {
            library.add(ex(ExerciseFilter.MOBILITY, 1, "duration"));
        }
        Set<String> mobility = library.stream().filter(ExerciseFilter::isMobility).map(Exercise::id)
            .collect(java.util.stream.Collectors.toSet());
        Week1PlanBuilder.Draft d = Week1PlanBuilder.build(LocalDate.parse("2026-10-05"), days(1, 3, 5), 15, library);
        for (TrainingPlan.Session s : d.sessions()) {
            assertTrue(s.items().stream().noneMatch(it -> mobility.contains(it.exerciseId().toHexString())));
        }
        assertTrue(Week1PlanBuilder.itemsFor("Toàn thân", 15, library).stream()
            .noneMatch(it -> mobility.contains(it.exerciseId().toHexString())));
    }

    @Test
    void gio_rieng_tung_ngay_thang_gio_mac_dinh_cua_khung() {
        assertEquals("07:15", Week1PlanBuilder.timeFor("07:15"));
        assertEquals("18:30", Week1PlanBuilder.timeFor("evening"));
        assertEquals("06:00", Week1PlanBuilder.timeFor("early_morning"));
        assertEquals("18:30", Week1PlanBuilder.timeFor("25:00"));          // giờ sai: về buổi tối
        Map<Integer, String> mixed = new LinkedHashMap<>();
        mixed.put(1, "05:45");
        mixed.put(3, "noon");
        Week1PlanBuilder.Draft d = Week1PlanBuilder.build(LocalDate.parse("2026-10-05"), mixed, 15, LIBRARY);
        assertEquals("05:45", d.sessions().get(0).scheduledTime());
        assertEquals("12:00", d.sessions().get(1).scheduledTime());
    }
}
