package vn.levelup.engagement.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;

class StreakCalculatorTest {

    private static final LocalDate THIS_WEEK = LocalDate.parse("2026-10-05");

    private static StreakCalculator.Week week(int weeksAgo, int target, int done, String status) {
        return new StreakCalculator.Week(THIS_WEEK.minusWeeks(weeksAgo).toString(), target, done, status);
    }

    @Test
    void counts_consecutive_kept_weeks_before_this_week() {
        List<StreakCalculator.Week> weeks = List.of(
            week(0, 3, 1, "in_progress"),       // tuần này chưa đạt: không cộng, không đứt
            week(1, 3, 3, "achieved"),
            week(2, 3, 0, "frozen"),
            week(3, 3, 3, "in_progress"),       // job chưa chốt nhưng đã đủ buổi
            week(4, 3, 1, "missed"),
            week(5, 3, 3, "achieved"));
        assertEquals(3, StreakCalculator.currentWeeks(weeks, THIS_WEEK));
    }

    @Test
    void this_week_adds_one_when_achieved() {
        List<StreakCalculator.Week> weeks = List.of(week(0, 3, 3, "achieved"), week(1, 3, 3, "achieved"));
        assertEquals(2, StreakCalculator.currentWeeks(weeks, THIS_WEEK));
    }

    @Test
    void gap_week_breaks_streak() {
        List<StreakCalculator.Week> weeks = List.of(week(1, 3, 3, "achieved"), week(3, 3, 3, "achieved"));
        assertEquals(1, StreakCalculator.currentWeeks(weeks, THIS_WEEK));
    }

    @Test
    void last_weeks_fill_missing_with_none_oldest_first() {
        List<StreakCalculator.Week> history = StreakCalculator.lastWeeks(List.of(week(0, 3, 1, "in_progress")),
            THIS_WEEK, 8);
        assertEquals(8, history.size());
        assertEquals(THIS_WEEK.minusWeeks(7).toString(), history.getFirst().weekStart());
        assertEquals("none", history.getFirst().status());
        assertEquals("in_progress", history.getLast().status());
    }

    @Test
    void history_starts_at_first_active_week() {
        // Người mới: chỉ còn tuần này
        List<StreakCalculator.Week> fresh = StreakCalculator.fromFirstActive(
            StreakCalculator.lastWeeks(List.of(week(0, 2, 0, "in_progress")), THIS_WEEK, 8));
        assertEquals(1, fresh.size());
        assertEquals("in_progress", fresh.getFirst().status());

        // Tuần trống ở giữa (bỏ app một tuần) vẫn giữ để thấy chỗ hổng
        List<StreakCalculator.Week> gap = StreakCalculator.fromFirstActive(StreakCalculator.lastWeeks(
            List.of(week(3, 3, 3, "achieved"), week(0, 3, 0, "in_progress")), THIS_WEEK, 8));
        assertEquals(4, gap.size());
        assertEquals("achieved", gap.getFirst().status());
        assertEquals("none", gap.get(1).status());

        // Chưa có tuần nào: vẫn trả tuần này
        assertEquals(1, StreakCalculator.fromFirstActive(StreakCalculator.lastWeeks(List.of(), THIS_WEEK, 8)).size());
    }
}
