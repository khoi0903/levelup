package vn.levelup.training.rules;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import vn.levelup.training.model.TrainingPlan;

/** Luật sửa một buổi trong kế hoạch (đổi bản 5 phút, rút ngắn, dời lịch), không đọc hay ghi database. */
public final class SessionRules {

    public static final int QUICK5_SEC = 5 * 60;
    public static final int QUICK5_REST_SEC = 20;
    /** Giây cho một lần lặp khi ước lượng thời lượng bài tính theo số lần. */
    static final int SEC_PER_REP = 3;
    static final int DEFAULT_REPS = 10;
    static final int DEFAULT_REST_SEC = 45;

    private SessionRules() {}

    /** Thời lượng ước lượng của một bài: số hiệp × (thời gian tập + nghỉ). */
    public static int estimateSec(TrainingPlan.Item item) {
        int sets = item.targetSets() == null ? 1 : Math.max(1, item.targetSets());
        int work = item.targetDurationSec() != null ? item.targetDurationSec()
            : (item.targetReps() == null ? DEFAULT_REPS : item.targetReps()) * SEC_PER_REP;
        int rest = item.restSec() == null ? DEFAULT_REST_SEC : item.restSec();
        return sets * (work + rest);
    }

    public static int estimateSec(List<TrainingPlan.Item> items) {
        return items.stream().mapToInt(SessionRules::estimateSec).sum();
    }

    /**
     * Cắt buổi cho vừa thời lượng: giảm hiệp của bài nhiều hiệp nhất trước (tối thiểu 1),
     * vẫn quá thì bỏ bớt bài cuối. Luôn giữ ít nhất một bài.
     */
    public static List<TrainingPlan.Item> fit(List<TrainingPlan.Item> items, int budgetSec, Integer maxRestSec) {
        List<TrainingPlan.Item> result = new ArrayList<>();
        for (TrainingPlan.Item i : items) {
            Integer rest = i.restSec();
            if (maxRestSec != null) {
                rest = rest == null ? maxRestSec : Math.min(rest, maxRestSec);
            }
            result.add(new TrainingPlan.Item(i.exerciseId(), i.targetSets(), i.targetReps(),
                i.targetDurationSec(), rest));
        }
        while (estimateSec(result) > budgetSec) {
            int idx = -1;
            int most = 1;
            for (int k = 0; k < result.size(); k++) {
                Integer sets = result.get(k).targetSets();
                if (sets != null && sets > most) {
                    most = sets;
                    idx = k;
                }
            }
            if (idx >= 0) {
                TrainingPlan.Item i = result.get(idx);
                result.set(idx, new TrainingPlan.Item(i.exerciseId(), i.targetSets() - 1, i.targetReps(),
                    i.targetDurationSec(), i.restSec()));
            } else if (result.size() > 1) {
                result.removeLast();
            } else {
                break;
            }
        }
        return result;
    }

    /** Bản 5 phút: nghỉ ngắn, ít hiệp, ít bài. */
    public static List<TrainingPlan.Item> quick5(List<TrainingPlan.Item> items) {
        return fit(items, QUICK5_SEC, QUICK5_REST_SEC);
    }

    /** Lỗi khi dời lịch, null nếu hợp lệ: chỉ trong tuần của kế hoạch và không trước hôm nay. */
    public static String rescheduleError(LocalDate weekStart, LocalDate today, LocalDate target) {
        if (target.isBefore(weekStart) || target.isAfter(weekStart.plusDays(6))) {
            return "DATE_OUTSIDE_WEEK";
        }
        if (target.isBefore(today)) {
            return "DATE_IN_PAST";
        }
        return null;
    }
}
