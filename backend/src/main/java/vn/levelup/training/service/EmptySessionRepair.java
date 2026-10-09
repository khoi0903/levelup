package vn.levelup.training.service;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;
import vn.levelup.coach.rules.SafeSessions;
import vn.levelup.identity.model.User;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.repository.ExerciseRepository;
import vn.levelup.training.rules.Week1PlanBuilder;

/**
 * Lưới an toàn: buổi còn planned mà không có bài (gặp trên máy thật, chưa rõ luồng nào làm rỗng) thì xếp lại
 * bài an toàn theo dụng cụ, chấn thương của người dùng và lưu. Log đủ thông tin để truy ra luồng gây lỗi.
 */
@Service
public class EmptySessionRepair {

    private static final Logger log = LoggerFactory.getLogger(EmptySessionRepair.class);

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;

    public EmptySessionRepair(MongoTemplate mongo, ExerciseRepository exercises) {
        this.mongo = mongo;
        this.exercises = exercises;
    }

    /** Trả kế hoạch đã sửa (đọc lại từ database), hoặc chính kế hoạch đó nếu không có buổi rỗng. */
    public TrainingPlan repair(User user, TrainingPlan plan) {
        if (plan == null || plan.sessions() == null) {
            return plan;
        }
        List<TrainingPlan.Session> empty = plan.sessions().stream()
            .filter(s -> "planned".equals(s.status()) && (s.items() == null || s.items().isEmpty()))
            .toList();
        if (empty.isEmpty()) {
            return plan;
        }
        User.Profile p = user.profile();
        Set<String> equipment = p == null || p.equipment() == null ? Set.of() : Set.copyOf(p.equipment());
        Set<String> injuries = user.injuries() == null ? Set.of() : user.injuries().stream()
            .filter(i -> !Boolean.FALSE.equals(i.active()) && i.bodyArea() != null)
            .map(User.Injury::bodyArea).collect(Collectors.toSet());
        ObjectId userId = new ObjectId(user.id());
        Set<String> disliked = ExerciseSwapService.dislikes(mongo, userId);
        List<Exercise> safe = SafeSessions.safeList(exercises.findByIsActiveTrue(),
                p == null ? null : p.location(), equipment, injuries).stream()
            .filter(e -> !disliked.contains(e.id())).toList();

        boolean changed = false;
        for (TrainingPlan.Session s : empty) {
            List<TrainingPlan.Item> items = Week1PlanBuilder.itemsFor(s.title(), s.durationMin(), safe);
            log.warn("[plan-repair] buổi rỗng user={} plan={} createdBy={} planCreatedAt={} session={} date={} "
                    + "variant={} adjustedReason={} -> xếp lại {} bài",
                user.id(), plan.id(), plan.createdBy(), plan.createdAt(), s.id(), s.scheduledDate(), s.variant(),
                s.adjustedReason(), items.size());
            if (items.isEmpty()) {
                continue;
            }
            mongo.updateFirst(Query.query(Criteria.where("_id").is(new ObjectId(plan.id())).and("userId").is(userId)
                    .and("sessions").elemMatch(Criteria.where("_id").is(s.id()).and("status").is("planned"))),
                new Update().set("sessions.$.items", items.stream().map(PlanSessionService::itemDocument).toList()),
                TrainingPlan.class);
            changed = true;
        }
        return changed ? mongo.findById(new ObjectId(plan.id()), TrainingPlan.class) : plan;
    }
}
