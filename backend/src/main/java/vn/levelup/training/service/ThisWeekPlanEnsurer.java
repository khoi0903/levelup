package vn.levelup.training.service;

import java.time.Clock;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;
import vn.levelup.coach.rules.SafeSessions;
import vn.levelup.identity.model.User;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.repository.ExerciseRepository;
import vn.levelup.training.rules.Week1PlanBuilder;

/**
 * Tuần mới mà người dùng chưa chốt tổng kết tuần thì chưa có kế hoạch active: trước đây app nhận lại kế hoạch tuần
 * trước (vòng tròn ✓ cũ, buổi cũ). Khi đọc kế hoạch: kích hoạt bản nháp tuần này (do tổng kết tuần tạo) nếu có,
 * không thì lập kế hoạch từ lịch rảnh như onboarding.
 */
@Service
public class ThisWeekPlanEnsurer {

    private static final Logger log = LoggerFactory.getLogger(ThisWeekPlanEnsurer.class);

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final Clock clock;

    public ThisWeekPlanEnsurer(MongoTemplate mongo, ExerciseRepository exercises, Clock clock) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.clock = clock;
    }

    /** Kế hoạch active của tuần này (tạo nếu cần); null nếu không lập được (ví dụ chưa có lịch rảnh, hết ngày). */
    public TrainingPlan ensure(User user) {
        ObjectId userId = new ObjectId(user.id());
        LocalDate today = LocalDates.today(user.timezone(), clock);
        String week = LocalDates.weekStart(today).toString();
        TrainingPlan active = activeFor(userId, week);
        if (active != null) {
            return active;
        }
        try {
            TrainingPlan draft = mongo.findOne(Query.query(Criteria.where("userId").is(userId)
                .and("weekStart").is(week).and("status").is("draft")), TrainingPlan.class);
            if (draft != null && draft.sessions() != null && !draft.sessions().isEmpty()) {
                mongo.updateFirst(Query.query(Criteria.where("_id").is(new ObjectId(draft.id()))
                    .and("status").is("draft")), Update.update("status", "active"), TrainingPlan.class);
                streak(userId, week, draft.sessions().size());
                log.info("[new-week] user={} week={} kích hoạt bản nháp tổng kết tuần", user.id(), week);
                return activeFor(userId, week);
            }
            Map<Integer, String> availability = new LinkedHashMap<>();
            if (user.availability() != null) {
                user.availability().forEach(a -> availability.putIfAbsent(a.weekday(), a.slotOrTime()));
            }
            int minutes = user.profile() == null || user.profile().sessionMinutes() == null ? 15
                : user.profile().sessionMinutes();
            Week1PlanBuilder.Draft built = Week1PlanBuilder.build(today, availability, minutes, safe(user, userId));
            if (!built.weekStart().toString().equals(week) || built.sessions().isEmpty()) {
                return null;                                     // hết ngày rảnh tuần này: chờ tuần sau
            }
            mongo.insert(new TrainingPlan(null, userId, week, "active", Math.max(1, built.sessions().size()),
                "rule", null, built.sessions(), clock.instant()));
            streak(userId, week, built.sessions().size());
            log.info("[new-week] user={} week={} lập kế hoạch từ lịch rảnh ({} buổi)", user.id(), week,
                built.sessions().size());
        } catch (DuplicateKeyException race) {
            // Request song song vừa tạo kế hoạch tuần này (unique userId + weekStart cho active)
        }
        return activeFor(userId, week);
    }

    private TrainingPlan activeFor(ObjectId userId, String week) {
        return mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(week)
            .and("status").is("active")), TrainingPlan.class);
    }

    private void streak(ObjectId userId, String week, int target) {
        mongo.upsert(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(week)),
            new Update().set("targetSessions", Math.max(1, Math.min(7, target)))
                .setOnInsert("completedSessions", 0).setOnInsert("status", "in_progress"), "weekly_streaks");
    }

    private List<Exercise> safe(User user, ObjectId userId) {
        User.Profile p = user.profile();
        Set<String> equipment = p == null || p.equipment() == null ? Set.of() : Set.copyOf(p.equipment());
        Set<String> injuries = user.injuries() == null ? Set.of() : user.injuries().stream()
            .filter(i -> !Boolean.FALSE.equals(i.active()) && i.bodyArea() != null)
            .map(User.Injury::bodyArea).collect(Collectors.toSet());
        Set<String> disliked = ExerciseSwapService.dislikes(mongo, userId);
        return SafeSessions.safeList(exercises.findByIsActiveTrue(), p == null ? null : p.location(), equipment,
                injuries).stream()
            .filter(e -> !disliked.contains(e.id())).toList();
    }
}
