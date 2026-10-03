package vn.levelup.motivation;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

/** Tính streak tuần từ weekly_streaks, không đọc database, để unit test. */
public final class StreakCalculator {

    public record Week(String weekStart, int targetSessions, int completedSessions, String status) {
        /** Tuần giữ được streak: đạt mục tiêu hoặc dùng thẻ đóng băng. */
        boolean kept() {
            return "achieved".equals(status) || "frozen".equals(status)
                || (targetSessions > 0 && completedSessions >= targetSessions && !"missed".equals(status));
        }
    }

    private StreakCalculator() {}

    /**
     * Số tuần liên tiếp giữ streak, tính lùi từ tuần trước. Tuần này chỉ cộng khi đã đạt,
     * chưa đạt thì chưa làm đứt streak vì tuần chưa kết thúc.
     */
    public static int currentWeeks(List<Week> weeks, LocalDate thisWeekStart) {
        Map<String, Week> byStart = index(weeks);
        int count = 0;
        LocalDate cursor = thisWeekStart.minusWeeks(1);
        while (true) {
            Week w = byStart.get(cursor.toString());
            if (w == null || !w.kept()) {
                break;
            }
            count++;
            cursor = cursor.minusWeeks(1);
        }
        Week thisWeek = byStart.get(thisWeekStart.toString());
        return thisWeek != null && thisWeek.kept() ? count + 1 : count;
    }

    /** n tuần gần nhất, cũ trước mới sau; tuần không có dữ liệu có status "none". */
    public static List<Week> lastWeeks(List<Week> weeks, LocalDate thisWeekStart, int n) {
        Map<String, Week> byStart = index(weeks);
        List<Week> result = new ArrayList<>();
        for (int i = n - 1; i >= 0; i--) {
            String start = thisWeekStart.minusWeeks(i).toString();
            result.add(byStart.getOrDefault(start, new Week(start, 0, 0, "none")));
        }
        return result;
    }

    private static Map<String, Week> index(List<Week> weeks) {
        return weeks.stream().collect(Collectors.toMap(Week::weekStart, Function.identity(), (a, b) -> a));
    }
}
