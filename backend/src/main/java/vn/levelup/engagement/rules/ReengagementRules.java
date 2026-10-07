package vn.levelup.engagement.rules;

import java.util.List;

/**
 * Bậc nhắc quay lại của F3 (users.reengagement.stage), không đọc hay ghi database, để unit test.
 * Thứ tự bậc: active → missed_1 → missed_2 → lapsed_7 → lapsed_14 → dormant.
 * Chốt ngày chỉ đẩy bậc lên; lưu buổi tập (WorkoutService) đưa về active.
 */
public final class ReengagementRules {

    public static final List<String> STAGES = List.of("active", "missed_1", "missed_2", "lapsed_7", "lapsed_14",
        "dormant");
    static final int LAPSED_7_DAYS = 7;
    static final int LAPSED_14_DAYS = 14;
    static final int DORMANT_DAYS = 30;

    private ReengagementRules() {}

    /** Bậc theo số buổi bỏ liên tiếp. */
    static String byMissed(int consecutiveMissed) {
        if (consecutiveMissed >= 2) {
            return "missed_2";
        }
        return consecutiveMissed == 1 ? "missed_1" : "active";
    }

    /** Bậc theo số ngày từ buổi tập gần nhất (chưa tập lần nào thì tính từ lúc tạo tài khoản). */
    static String byDays(long daysSinceLastWorkout) {
        if (daysSinceLastWorkout >= DORMANT_DAYS) {
            return "dormant";
        }
        if (daysSinceLastWorkout >= LAPSED_14_DAYS) {
            return "lapsed_14";
        }
        return daysSinceLastWorkout >= LAPSED_7_DAYS ? "lapsed_7" : "active";
    }

    /** Bậc mới sau khi chốt ngày: bậc cao nhất trong bậc hiện tại, bậc theo buổi bỏ và bậc theo số ngày. */
    public static String next(String current, int consecutiveMissed, long daysSinceLastWorkout) {
        String best = current == null || !STAGES.contains(current) ? "active" : current;
        for (String candidate : List.of(byMissed(consecutiveMissed), byDays(daysSinceLastWorkout))) {
            if (STAGES.indexOf(candidate) > STAGES.indexOf(best)) {
                best = candidate;
            }
        }
        return best;
    }

    /**
     * Còn được gửi tin quay lại trong bậc này không: lapsed_7 một tin, lapsed_14 tối đa 2 tin
     * (mỗi tuần một tin, chặn bằng dedupeKey theo tuần). Bậc khác không gửi tin quay lại.
     */
    public static boolean lapsedMessageDue(String stage, int messagesInStage) {
        return switch (stage) {
            case "lapsed_7" -> messagesInStage < 1;
            case "lapsed_14" -> messagesInStage < 2;
            default -> false;
        };
    }
}
