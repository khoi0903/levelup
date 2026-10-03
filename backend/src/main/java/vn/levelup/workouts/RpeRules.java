package vn.levelup.workouts;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Optional;

import vn.levelup.plans.TrainingPlan;

/** Chỉnh buổi kế tiếp theo RPE và vùng đau của buổi vừa tập, không đọc hay ghi database. */
public final class RpeRules {

    static final int MAX_SETS = 6;
    static final int EXTRA_REPS = 2;
    static final int EASY_MAX = 5;
    static final int HARD_MIN = 9;
    /** Nghỉ từ chừng này ngày trở lên rồi tập lại thì có huy hiệu comeback_days_7. */
    static final Duration COMEBACK_GAP = Duration.ofDays(7);

    private RpeRules() {}

    public record Adjustment(String reason, List<TrainingPlan.Item> items) {}

    /**
     * RPE ≤ 5: thêm 1 hiệp mỗi bài (tối đa 6), bài đã đủ 6 hiệp thì thêm 2 lần.
     * RPE 6–8: giữ nguyên. RPE ≥ 9 hoặc có vùng đau: bớt 1 hiệp (tối thiểu 1).
     * Không có thay đổi thực sự thì trả rỗng.
     */
    public static Optional<Adjustment> adjust(List<TrainingPlan.Item> items, Integer rpe, List<String> painAreas) {
        if (items == null || items.isEmpty()) {
            return Optional.empty();
        }
        boolean pain = painAreas != null && !painAreas.isEmpty();
        List<TrainingPlan.Item> result;
        String reason;
        if (pain || (rpe != null && rpe >= HARD_MIN)) {
            reason = pain ? "rpe_pain" : "rpe_hard";
            result = items.stream().map(i -> new TrainingPlan.Item(i.exerciseId(),
                i.targetSets() == null ? null : Math.max(1, i.targetSets() - 1),
                i.targetReps(), i.targetDurationSec(), i.restSec())).toList();
        } else if (rpe != null && rpe <= EASY_MAX) {
            reason = "rpe_easy";
            result = items.stream().map(RpeRules::harder).toList();
        } else {
            return Optional.empty();
        }
        return result.equals(items) ? Optional.empty() : Optional.of(new Adjustment(reason, result));
    }

    private static TrainingPlan.Item harder(TrainingPlan.Item i) {
        int sets = i.targetSets() == null ? 1 : i.targetSets();
        if (sets < MAX_SETS) {
            return new TrainingPlan.Item(i.exerciseId(), sets + 1, i.targetReps(), i.targetDurationSec(), i.restSec());
        }
        if (i.targetReps() != null) {
            return new TrainingPlan.Item(i.exerciseId(), i.targetSets(), i.targetReps() + EXTRA_REPS,
                i.targetDurationSec(), i.restSec());
        }
        return i;
    }

    /** Buổi này là lần quay lại sau ít nhất 7 ngày không tập. */
    public static boolean isComeback(Instant previousWorkoutEnd, Instant startedAt) {
        return previousWorkoutEnd != null && !Duration.between(previousWorkoutEnd, startedAt).minus(COMEBACK_GAP)
            .isNegative();
    }
}
