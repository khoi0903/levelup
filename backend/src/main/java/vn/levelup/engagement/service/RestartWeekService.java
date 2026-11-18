package vn.levelup.engagement.service;

import java.time.Clock;
import java.time.LocalDate;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;
import vn.levelup.engagement.rules.RestartRules;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.repository.ExerciseRepository;
import vn.levelup.training.rules.ExerciseFilter;
import vn.levelup.training.rules.Week1PlanBuilder;
import vn.levelup.training.service.ExerciseSwapService;


/**
 * F3: khi người dùng vào bậc lapsed_7 / lapsed_14, tuần này thành "tuần khởi động lại" nhẹ hơn:
 * - đã có kế hoạch active của tuần: các buổi còn lại (từ hôm nay, còn planned) → light, ≤ 10 phút, bớt 1 hiệp;
 * - chưa có: tạo kế hoạch mới bằng Week1PlanBuilder với buổi 10 phút, chỉ gồm bài an toàn.
 * Chạy lại an toàn: buổi đã có adjustedReason restart_lapsed thì bỏ qua; kế hoạch chỉ tạo khi tuần chưa có.
 */
@Service
public class RestartWeekService {

    public static final String REASON = "restart_lapsed";
    public static final int RESTART_MINUTES = 10;

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final Clock clock;

    public RestartWeekService(MongoTemplate mongo, ExerciseRepository exercises, Clock clock) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.clock = clock;
    }

    /** @return số buổi được làm nhẹ hoặc tạo mới */
    public int restart(ObjectId userId, Document user, LocalDate today) {
        String weekStart = LocalDates.weekStart(today).toString();
        TrainingPlan plan = mongo.findOne(Query.query(Criteria.where("userId").is(userId)
            .and("weekStart").is(weekStart).and("status").is("active")), TrainingPlan.class);
        return plan == null ? createPlan(userId, user, today, weekStart) : lighten(plan, today);
    }

    private int lighten(TrainingPlan plan, LocalDate today) {
        int changed = 0;
        for (TrainingPlan.Session s : plan.sessions()) {
            if (!"planned".equals(s.status()) || REASON.equals(s.adjustedReason())
                || s.scheduledDate().compareTo(today.toString()) < 0) {
                continue;
            }
            TrainingPlan.Session light = RestartRules.lighten(s, RESTART_MINUTES, REASON);
            Update update = new Update().set("sessions.$.variant", light.variant())
                .set("sessions.$.durationMin", light.durationMin())
                .set("sessions.$.adjustedReason", REASON);
            for (int i = 0; light.items() != null && i < light.items().size(); i++) {
                update.set("sessions.$.items." + i + ".targetSets", light.items().get(i).targetSets());
            }
            // Khớp cả trạng thái: buổi vừa được tập/đổi ở nơi khác thì không đè
            var result = mongo.updateFirst(Query.query(Criteria.where("_id").is(new ObjectId(plan.id()))
                .and("sessions").elemMatch(Criteria.where("_id").is(s.id()).and("status").is("planned")
                    .and("adjustedReason").ne(REASON))), update, TrainingPlan.class);
            changed += (int) result.getModifiedCount();
        }
        return changed;
    }

    private int createPlan(ObjectId userId, Document user, LocalDate today, String weekStart) {
        Document profile = user.get("profile", new Document());
        Map<Integer, String> availability = new LinkedHashMap<>();
        for (Document slot : user.getList("availability", Document.class, List.of())) {
            if (slot.get("weekday") instanceof Number w && slot.getString("slot") != null) {
                availability.putIfAbsent(w.intValue(),
                    slot.getString("time") != null ? slot.getString("time") : slot.getString("slot"));
            }
        }
        Set<String> equipment = new HashSet<>(profile.getList("equipment", String.class, List.of()));
        Set<String> injuries = new HashSet<>();
        for (Document injury : user.getList("injuries", Document.class, List.of())) {
            if (!Boolean.FALSE.equals(injury.getBoolean("active")) && injury.getString("bodyArea") != null) {
                injuries.add(injury.getString("bodyArea"));
            }
        }
        Set<String> disliked = ExerciseSwapService.dislikes(mongo, userId);
        List<Exercise> safe = ExerciseFilter.forUser(exercises.findByIsActiveTrue(), profile.getString("location"),
            equipment, injuries).stream().filter(e -> !disliked.contains(e.id())).toList();
        Week1PlanBuilder.Draft draft = Week1PlanBuilder.build(today, availability, RESTART_MINUTES, safe);
        if (draft.sessions().isEmpty()) {
            return 0;
        }
        List<TrainingPlan.Session> sessions = draft.sessions().stream()
            .map(s -> RestartRules.markRestart(s, REASON)).toList();
        TrainingPlan plan = new TrainingPlan(null, userId, weekStart, "active", sessions.size(), "rule",
            "Tuần khởi động lại nhẹ sau thời gian nghỉ", sessions, clock.instant());
        // Hai lần chốt song song: chỉ chèn khi tuần vẫn chưa có kế hoạch active
        if (mongo.exists(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(weekStart)
            .and("status").is("active")), TrainingPlan.class)) {
            return 0;
        }
        mongo.insert(plan);
        mongo.upsert(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(weekStart)),
            new Update().setOnInsert("targetSessions", sessions.size()).setOnInsert("completedSessions", 0)
                .setOnInsert("status", "in_progress"), "weekly_streaks");
        return sessions.size();
    }
}
