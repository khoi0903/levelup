package vn.levelup.training.dto;

import java.util.List;
import java.util.Map;
import vn.levelup.training.model.TrainingPlan;

/** Kế hoạch gửi về app: thêm tên bài tập để app hiển thị ngay, không phải gọi thêm. */
public record PlanView(
    String id,
    String weekStart,
    String status,
    Integer targetSessions,
    List<SessionView> sessions
) {
    public record SessionView(String id, String scheduledDate, String scheduledTime, String title,
                              Integer durationMin, String variant, String status, List<ItemView> items,
                              String adjustedReason) {}

    public record ItemView(String exerciseId, String nameVi, Integer sets, Integer reps,
                           Integer durationSec, Integer restSec) {}

    public static PlanView of(TrainingPlan plan, Map<String, String> exerciseNames) {
        List<SessionView> sessions = plan.sessions() == null ? List.of() : plan.sessions().stream()
            .map(s -> new SessionView(s.id().toHexString(), s.scheduledDate(), s.scheduledTime(), s.title(),
                s.durationMin(), s.variant(), s.status(),
                s.items() == null ? List.of() : s.items().stream()
                    .map(i -> new ItemView(i.exerciseId().toHexString(),
                        exerciseNames.get(i.exerciseId().toHexString()),
                        i.targetSets(), i.targetReps(), i.targetDurationSec(), i.restSec()))
                    .toList(), s.adjustedReason()))
            .toList();
        return new PlanView(plan.id(), plan.weekStart(), plan.status(), plan.targetSessions(), sessions);
    }
}
