package vn.levelup.training.rules;

import java.util.List;
import vn.levelup.training.model.TrainingPlan;


/** Luật điều chỉnh check-in thuần, không đọc hay ghi database. */
public final class CheckinAdjuster {

    private CheckinAdjuster() {}

    public record Adjustment(boolean adjusted, TrainingPlan.Session session) {}

    public static Adjustment adjust(TrainingPlan.Session session, String energy, String sleep) {
        if ("tired".equals(energy) || "lt6".equals(sleep)) {
            List<TrainingPlan.Item> items = session.items() == null ? null : session.items().stream()
                .map(i -> new TrainingPlan.Item(i.exerciseId(),
                    i.targetSets() == null ? null : Math.max(1, i.targetSets() - 1),
                    i.targetReps(), i.targetDurationSec(), i.restSec()))
                .toList();
            return new Adjustment(true, copy(session, "light", items, "checkin_tired"));
        }
        if ("energized".equals(energy)) {
            return new Adjustment(true, copy(session, "advanced", session.items(), "checkin_energized"));
        }
        return new Adjustment(false, session);
    }

    private static TrainingPlan.Session copy(TrainingPlan.Session s, String variant,
                                             List<TrainingPlan.Item> items, String reason) {
        return new TrainingPlan.Session(s.id(), s.scheduledDate(), s.scheduledTime(), s.title(),
            s.durationMin(), variant, s.status(), items, reason);
    }
}
