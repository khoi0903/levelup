package vn.levelup.training.service;

import java.time.LocalDate;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

import org.bson.types.ObjectId;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.rules.RpeRules;


/** Áp {@link RpeRules} vào buổi planned kế tiếp trong kế hoạch active (tuần này hoặc tuần sau). */
@Service
public class RpeAdjuster {

    private final MongoTemplate mongo;

    public RpeAdjuster(MongoTemplate mongo) {
        this.mongo = mongo;
    }

    /** @return lý do đã chỉnh (rpe_easy, rpe_hard, rpe_pain), rỗng nếu không chỉnh. */
    public Optional<String> adjustNext(ObjectId userId, LocalDate workoutDate, ObjectId doneSessionId,
                                       Integer rpe, List<String> painAreas) {
        String weekStart = LocalDates.weekStart(workoutDate).toString();
        List<TrainingPlan> active = mongo.find(Query.query(Criteria.where("userId").is(userId)
            .and("status").is("active").and("weekStart").gte(weekStart)).with(Sort.by("weekStart")).limit(2),
            TrainingPlan.class);
        for (TrainingPlan plan : active) {
            Optional<TrainingPlan.Session> next = plan.sessions().stream()
                .filter(s -> "planned".equals(s.status()) && !s.id().equals(doneSessionId))
                .filter(s -> s.scheduledDate().compareTo(workoutDate.toString()) >= 0)
                .min(Comparator.comparing(TrainingPlan.Session::scheduledDate)
                    .thenComparing(s -> s.scheduledTime() == null ? "" : s.scheduledTime()));
            if (next.isEmpty()) {
                continue;
            }
            TrainingPlan.Session session = next.get();
            Optional<RpeRules.Adjustment> adjustment = RpeRules.adjust(session.items(), rpe, painAreas);
            adjustment.ifPresent(a -> mongo.updateFirst(
                PlanSessionService.plannedSession(plan, userId, session.id()),
                new Update().set("sessions.$.items", a.items().stream().map(PlanSessionService::itemDocument).toList())
                    .set("sessions.$.adjustedReason", a.reason()),
                TrainingPlan.class));
            return adjustment.map(RpeRules.Adjustment::reason);
        }
        return Optional.empty();
    }
}
