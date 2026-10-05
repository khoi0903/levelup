package vn.levelup.workouts;

import java.util.List;

/** Kết quả trả cho màn Kết quả (F2b): tiến độ tuần, kỷ lục mới, huy hiệu mới. */
public record WorkoutResponse(
    String workoutId,
    String localDate,
    long durationSec,
    boolean countsForStreak,
    boolean duplicate,          // true khi app gửi lại cùng clientId
    Week week,
    List<Record> personalRecords,
    List<Achievement> newAchievements,
    int kcalBurned              // ước tính: MET × cân nặng × thời gian (WorkoutRules.kcalBurned)
) {
    public record Week(String weekStart, int targetSessions, int completedSessions, String status) {}

    /** metric: max_reps | max_weight | max_duration. */
    public record Record(String exerciseId, String nameVi, String metric, double value, Double previous) {}

    public record Achievement(String code, String nameVi, String descriptionVi) {}
}
