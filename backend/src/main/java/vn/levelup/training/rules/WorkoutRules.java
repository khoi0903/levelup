package vn.levelup.training.rules;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import vn.levelup.training.dto.WorkoutRequest;

/** Luật của F2 không đọc hay ghi database, để unit test. */
public final class WorkoutRules {

    /** Buổi từ 5 phút mới tính streak (AGENTS.md). */
    public static final int MIN_STREAK_SEC = 300;

    /** Mốc số buổi có huy hiệu, khớp mongo/seed/achievements.json. */
    public static final Map<Integer, String> SESSION_MILESTONES = Map.of(
        1, "sessions_1", 10, "sessions_10", 25, "sessions_25", 50, "sessions_50");

    private WorkoutRules() {}

    /** MET khi bài chưa có số liệu: mức vận động vừa phải. */
    public static final double DEFAULT_MET = 4.0;
    /** Chưa có cân nặng nào: dùng mức trung bình người Việt trưởng thành. */
    public static final double DEFAULT_WEIGHT_KG = 60.0;

    /**
     * Calo đốt ước tính: MET × cân nặng (kg) × thời gian (giờ). Thời lượng cả buổi chia cho từng bài theo số hiệp,
     * nên MET dùng là trung bình có trọng số theo số hiệp. Đã gồm thời gian nghỉ giữa hiệp → là ước tính, không đo.
     */
    public static int kcalBurned(List<WorkoutRequest.SetLog> sets, Map<String, Double> metByExercise,
                                 long durationSec, double weightKg) {
        if (sets.isEmpty() || durationSec <= 0 || weightKg <= 0) {
            return 0;
        }
        double sum = 0;
        for (WorkoutRequest.SetLog s : sets) {
            Double met = metByExercise.get(s.exerciseId());
            sum += met == null || met <= 0 ? DEFAULT_MET : met;
        }
        double met = sum / sets.size();
        return (int) Math.round(met * weightKg * durationSec / 3600.0);
    }

    public static boolean countsForStreak(long durationSec) {
        return durationSec >= MIN_STREAK_SEC;
    }

    /** Huy hiệu số buổi vừa đạt, nếu người dùng chưa có. */
    public static Optional<String> sessionMilestone(long countedSessions, Set<String> owned) {
        String code = SESSION_MILESTONES.get((int) Math.min(countedSessions, Integer.MAX_VALUE));
        return code == null || owned.contains(code) ? Optional.empty() : Optional.of(code);
    }

    /** Một chỉ số tốt nhất của một bài trong buổi này, kèm hiệp đạt được nó. */
    public record Best(String exerciseId, String metric, double value, int setIndex) {}

    /**
     * Chỉ số tốt nhất theo từng bài: max_reps, max_weight, max_duration.
     * Hiệp không có số (null hoặc 0) thì bỏ qua; hòa thì giữ hiệp đầu tiên.
     */
    public static List<Best> bests(List<WorkoutRequest.SetLog> sets) {
        Map<String, Best> best = new LinkedHashMap<>();
        for (WorkoutRequest.SetLog s : sets) {
            offer(best, s.exerciseId(), "max_reps", s.reps() == null ? 0 : s.reps(), s.setIndex());
            offer(best, s.exerciseId(), "max_weight", s.weightKg() == null ? 0 : s.weightKg(), s.setIndex());
            offer(best, s.exerciseId(), "max_duration", s.durationSec() == null ? 0 : s.durationSec(), s.setIndex());
        }
        return new ArrayList<>(best.values());
    }

    private static void offer(Map<String, Best> best, String exerciseId, String metric, double value, int setIndex) {
        if (value <= 0) {
            return;
        }
        String key = exerciseId + "/" + metric;
        Best current = best.get(key);
        if (current == null || value > current.value()) {
            best.put(key, new Best(exerciseId, metric, value, setIndex));
        }
    }

    /**
     * Có phải kỷ lục mới không. Lần đầu tập một bài chỉ lưu mốc, không báo kỷ lục,
     * để buổi đầu tiên không bị tràn thông báo "kỷ lục".
     */
    public static boolean isNewRecord(Double previous, double value) {
        return previous != null && value > previous;
    }

    /** Trạng thái tuần sau khi cộng một buổi. Tuần đã chốt (frozen, missed) thì không đổi. */
    public static String weekStatus(String status, int completed, int target) {
        if ("in_progress".equals(status) && completed >= Math.max(1, target)) {
            return "achieved";
        }
        return status;
    }
}
