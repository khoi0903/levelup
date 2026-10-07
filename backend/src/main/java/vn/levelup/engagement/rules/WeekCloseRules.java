package vn.levelup.engagement.rules;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/** Quyết định chốt tuần theo flowchart F4, không đọc hay ghi database, để unit test. */
public final class WeekCloseRules {

    public static final int MAX_FREEZES = 2;
    /** Mỗi chừng này tuần đạt liên tiếp thì được thêm một thẻ đóng băng. */
    public static final int WEEKS_PER_FREEZE = 4;
    static final int[] STREAK_BADGES = {2, 4, 8};

    private WeekCloseRules() {}

    /**
     * @param status         trạng thái tuần (in_progress | achieved | frozen | missed)
     * @param freezeEvent    "earned" | "used" | null, ghi vào weekly_streaks.freezeEvent
     * @param newAchievements mã huy hiệu mới (streak_2/4/8, streak_freeze_1)
     */
    public record Decision(String status, String freezeEvent, int currentWeeks, int bestWeeks,
                           int freezesAvailable, List<String> newAchievements) {}

    /**
     * @param achievedRunBefore số tuần "achieved" liên tiếp ngay trước tuần này (tuần frozen làm đứt chuỗi)
     */
    public static Decision decide(String status, int completed, int target, int freezesAvailable,
                                  int currentWeeks, int bestWeeks, int achievedRunBefore, Set<String> owned) {
        boolean achieved = "achieved".equals(status) || completed >= Math.max(1, target);
        List<String> earned = new ArrayList<>();
        String newStatus;
        String freezeEvent = null;
        int weeks = currentWeeks;
        int freezes = freezesAvailable;
        if (achieved) {
            newStatus = "achieved";
            weeks = currentWeeks + 1;
            if ((achievedRunBefore + 1) % WEEKS_PER_FREEZE == 0 && freezes < MAX_FREEZES) {
                freezes++;
                freezeEvent = "earned";
            }
        } else if (freezes > 0) {
            newStatus = "frozen";
            freezes--;
            freezeEvent = "used";
            if (!owned.contains("streak_freeze_1")) {
                earned.add("streak_freeze_1");
            }
        } else {
            newStatus = "missed";
            weeks = 0;
        }
        for (int n : STREAK_BADGES) {
            String code = "streak_" + n;
            if (weeks >= n && !owned.contains(code)) {
                earned.add(code);
            }
        }
        return new Decision(newStatus, freezeEvent, weeks, Math.max(bestWeeks, weeks), freezes, earned);
    }
}
