package vn.levelup.reviews;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.List;
import java.util.Set;

import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;

import vn.levelup.plans.TrainingPlan;

class ReviewRulesTest {

    static final LocalDate NEXT = LocalDate.of(2026, 10, 5);      // Thứ Hai

    static TrainingPlan.Session session(String date, String variant, int minutes, int sets) {
        return new TrainingPlan.Session(new ObjectId(), date, "18:30", "Toàn thân", minutes, variant, "completed",
            List.of(new TrainingPlan.Item(new ObjectId(), sets, 10, null, 45)));
    }

    @Test
    void deXuatTheoTyLeHoanThanhVaRpe() {
        assertEquals("increase", ReviewRules.recommendation(3, 3, 6.5));
        assertEquals("increase", ReviewRules.recommendation(3, 3, 7.0));
        assertEquals("increase", ReviewRules.recommendation(4, 3, null));
        assertEquals("keep", ReviewRules.recommendation(3, 3, 8.0));        // đủ buổi nhưng quá nặng
        assertEquals("keep", ReviewRules.recommendation(2, 3, 5.0));        // 67%
        assertEquals("keep", ReviewRules.recommendation(3, 5, null));       // 60%
        assertEquals("decrease", ReviewRules.recommendation(1, 3, 5.0));    // 33%
        assertEquals("decrease", ReviewRules.recommendation(0, 3, null));
        assertEquals(67, ReviewRules.completionPct(2, 3));
        assertEquals(100, ReviewRules.completionPct(5, 3));
    }

    @Test
    void tuanSauDoiNgayVaDieuChinhHiepThoiLuong() {
        List<TrainingPlan.Session> week = List.of(
            session("2026-09-30", "normal", 15, 2),             // Thứ Tư
            session("2026-09-28", "normal", 15, 2),             // Thứ Hai
            session("2026-10-02", "quick5", 5, 1));             // Thứ Sáu đã bị rút gọn
        List<TrainingPlan.Session> up = ReviewRules.nextWeek(week, NEXT, "increase");
        assertEquals(List.of("2026-10-05", "2026-10-07", "2026-10-09"),
            up.stream().map(TrainingPlan.Session::scheduledDate).toList());
        assertTrue(up.stream().allMatch(s -> "planned".equals(s.status()) && "normal".equals(s.variant())));
        assertTrue(up.stream().allMatch(s -> s.durationMin() == 20));       // buổi quick5 lấy lại 15 phút
        assertTrue(up.stream().allMatch(s -> s.items().get(0).targetSets() == 3));

        List<TrainingPlan.Session> down = ReviewRules.nextWeek(week, NEXT, "decrease");
        assertTrue(down.stream().allMatch(s -> s.durationMin() == 10 && s.items().get(0).targetSets() == 1));
        List<TrainingPlan.Session> keep = ReviewRules.nextWeek(week, NEXT, "keep");
        assertTrue(keep.stream().allMatch(s -> s.durationMin() == 15 && s.items().get(0).targetSets() == 2));
        // id mới, không dùng lại id tuần này
        assertTrue(up.stream().noneMatch(s -> week.stream().anyMatch(w -> w.id().equals(s.id()))));
    }

    @Test
    void nguoiDungChinhSoBuoiVaSoPhut() {
        List<TrainingPlan.Session> draft = ReviewRules.nextWeek(List.of(
            session("2026-09-28", "normal", 15, 2), session("2026-09-30", "normal", 15, 2),
            session("2026-10-02", "normal", 15, 2)), NEXT, "keep");

        List<TrainingPlan.Session> two = ReviewRules.adjust(draft, NEXT, 2, 30);
        assertEquals(List.of("2026-10-05", "2026-10-07"), two.stream().map(TrainingPlan.Session::scheduledDate).toList());
        assertTrue(two.stream().allMatch(s -> s.durationMin() == 30));

        List<TrainingPlan.Session> five = ReviewRules.adjust(draft, NEXT, 5, null);
        assertEquals(5, five.size());
        assertEquals(5, Set.copyOf(five.stream().map(TrainingPlan.Session::scheduledDate).toList()).size());
        assertTrue(five.stream().allMatch(s -> s.durationMin() == 15 && !s.items().isEmpty()));

        assertEquals(7, ReviewRules.adjust(draft, NEXT, 7, null).size());
    }

    @Test
    void loiTongKetTuJsonHoacCauMau() {
        assertTrue(ReviewTexts.parse("{\"win\":\"a\",\"improve\":\"b\"}").isEmpty());
        assertTrue(ReviewTexts.parse("không phải JSON").isEmpty());
        assertEquals("Thắng", ReviewTexts.parse("```json\n{\"win\":\"Thắng\",\"improve\":\"Cải thiện\","
            + "\"nextWeekSummary\":\"3 buổi\"}\n```").orElseThrow().win());

        ReviewTexts.Facts facts = new ReviewTexts.Facts("Minh", "strict", 2, 3, 30, 6.0, "keep",
            List.of(), null, 0, null, 3, 15);
        ReviewTexts.Texts t = ReviewTexts.fallback(facts);
        assertEquals("Minh, tuần này bạn hoàn thành 2 buổi.", t.win());
        assertTrue(t.nextWeekSummary().startsWith("Tuần sau: 3 buổi"));
        ReviewTexts.Texts pr = ReviewTexts.fallback(new ReviewTexts.Facts("Minh", "funny", 3, 3, 45, 6.0,
            "increase", List.of("Squat: 14 lần"), -0.5, 4, 1800, 3, 20));
        assertTrue(pr.win().contains("Squat: 14 lần"));
    }
}
