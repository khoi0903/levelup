package vn.levelup.engagement.rules;

import java.util.List;
import vn.levelup.training.model.TrainingPlan;


/** Làm nhẹ một buổi cho tuần khởi động lại. Không đọc database, để unit test. */
public final class RestartRules {

    private RestartRules() {}

    /** light, tối đa maxMinutes phút, mỗi bài bớt 1 hiệp (ít nhất 1), ghi lý do. */
    public static TrainingPlan.Session lighten(TrainingPlan.Session s, int maxMinutes, String reason) {
        Integer minutes = s.durationMin() == null ? maxMinutes : Math.min(s.durationMin(), maxMinutes);
        List<TrainingPlan.Item> items = s.items() == null ? null : s.items().stream()
            .map(i -> new TrainingPlan.Item(i.exerciseId(),
                i.targetSets() == null ? null : Math.max(1, i.targetSets() - 1),
                i.targetReps(), i.targetDurationSec(), i.restSec()))
            .toList();
        return new TrainingPlan.Session(s.id(), s.scheduledDate(), s.scheduledTime(), s.title(), minutes,
            "light", s.status(), items, reason);
    }

    /** Buổi của kế hoạch khởi động lại mới tạo: giữ nguyên bài, chỉ đánh dấu light + lý do. */
    public static TrainingPlan.Session markRestart(TrainingPlan.Session s, String reason) {
        return new TrainingPlan.Session(s.id(), s.scheduledDate(), s.scheduledTime(), s.title(), s.durationMin(),
            "light", s.status(), s.items(), reason);
    }
}
