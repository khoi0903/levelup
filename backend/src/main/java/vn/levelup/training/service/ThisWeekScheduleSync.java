package vn.levelup.training.service;

import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;
import vn.levelup.coach.rules.SafeSessions;
import vn.levelup.identity.dto.OnboardingRequest;
import vn.levelup.identity.model.User;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.repository.ExerciseRepository;
import vn.levelup.training.rules.Week1PlanBuilder;

/**
 * Đổi lịch rảnh trong Cài đặt thì áp dụng ngay cho phần còn lại của tuần này (từ hôm nay theo giờ máy chủ):
 * ngày mới thêm chưa có buổi → tạo buổi (bài an toàn); ngày bị bỏ → xoá buổi còn planned ở ngày đó.
 * Buổi đã tập, đã bỏ, đã nghỉ và các ngày đã qua giữ nguyên. Chỉ tiêu tuần = số buổi của tuần sau khi đổi.
 */
@Service
public class ThisWeekScheduleSync {

    private static final Logger log = LoggerFactory.getLogger(ThisWeekScheduleSync.class);

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final Clock clock;

    public ThisWeekScheduleSync(MongoTemplate mongo, ExerciseRepository exercises, Clock clock) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.clock = clock;
    }

    public void apply(User user, List<OnboardingRequest.Slot> availability) {
        ObjectId userId = new ObjectId(user.id());
        LocalDate today = LocalDates.today(user.timezone(), clock);
        LocalDate weekStart = LocalDates.weekStart(today);
        TrainingPlan plan = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("status").is("active")
            .and("weekStart").is(weekStart.toString())), TrainingPlan.class);
        if (plan == null) {
            return;
        }
        Map<Integer, String> wanted = new HashMap<>();
        availability.forEach(s -> wanted.put(s.weekday(), s.time() != null ? s.time() : s.slot()));
        List<TrainingPlan.Session> sessions = plan.sessions() == null ? List.of() : plan.sessions();

        // 1. Bỏ buổi planned từ hôm nay trở đi ở ngày không còn trong lịch
        List<ObjectId> removed = sessions.stream()
            .filter(s -> "planned".equals(s.status()) && !LocalDate.parse(s.scheduledDate()).isBefore(today))
            .filter(s -> !wanted.containsKey(LocalDate.parse(s.scheduledDate()).getDayOfWeek().getValue()))
            .map(TrainingPlan.Session::id).toList();

        // 2. Thêm buổi cho ngày mới (từ hôm nay tới Chủ nhật) chưa có buổi nào
        Set<String> taken = sessions.stream().map(TrainingPlan.Session::scheduledDate).collect(Collectors.toSet());
        int minutes = user.profile() == null || user.profile().sessionMinutes() == null ? 15
            : user.profile().sessionMinutes();
        List<Exercise> safe = null;
        List<Document> added = new ArrayList<>();
        int index = sessions.size() - removed.size();
        for (LocalDate d = today; !d.isAfter(weekStart.plusDays(6)); d = d.plusDays(1)) {
            String slot = wanted.get(d.getDayOfWeek().getValue());
            if (slot == null || taken.contains(d.toString())) {
                continue;
            }
            if (safe == null) {
                safe = safeExercises(user, userId);
            }
            String title = Week1PlanBuilder.titleFor(index++);
            List<TrainingPlan.Item> items = Week1PlanBuilder.itemsFor(title, minutes, safe);
            if (items.isEmpty()) {
                continue;
            }
            added.add(new Document("_id", new ObjectId()).append("scheduledDate", d.toString())
                .append("scheduledTime", Week1PlanBuilder.timeFor(slot)).append("title", title)
                .append("durationMin", Math.max(10, Math.min(15, minutes))).append("variant", "normal")
                .append("status", "planned")
                .append("items", items.stream().map(PlanSessionService::itemDocument).toList()));
        }
        // 3. Đổi giờ các buổi planned còn lại (từ hôm nay) nếu giờ của ngày đó đã đổi
        Map<ObjectId, String> retimed = new HashMap<>();
        for (TrainingPlan.Session s : sessions) {
            LocalDate date = LocalDate.parse(s.scheduledDate());
            String slot = wanted.get(date.getDayOfWeek().getValue());
            if (slot == null || !"planned".equals(s.status()) || date.isBefore(today) || removed.contains(s.id())) {
                continue;
            }
            String time = Week1PlanBuilder.timeFor(slot);
            if (!time.equals(s.scheduledTime())) {
                retimed.put(s.id(), time);
            }
        }
        if (removed.isEmpty() && added.isEmpty() && retimed.isEmpty()) {
            return;
        }

        Query mine = Query.query(Criteria.where("_id").is(new ObjectId(plan.id())).and("userId").is(userId));
        if (!removed.isEmpty()) {
            mongo.updateFirst(mine, new Update().pull("sessions",
                Query.query(Criteria.where("_id").in(removed).and("status").is("planned")).getQueryObject()),
                TrainingPlan.class);
        }
        if (!added.isEmpty()) {
            mongo.updateFirst(mine, new Update().push("sessions").each(added.toArray()), TrainingPlan.class);
        }
        retimed.forEach((id, time) -> mongo.updateFirst(
            Query.query(Criteria.where("_id").is(new ObjectId(plan.id())).and("userId").is(userId)
                .and("sessions._id").is(id)),
            Update.update("sessions.$.scheduledTime", time), TrainingPlan.class));
        int target = Math.max(1, Math.min(7, sessions.size() - removed.size() + added.size()));
        mongo.updateFirst(mine, Update.update("targetSessions", target), TrainingPlan.class);
        mongo.updateFirst(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(weekStart.toString())),
            Update.update("targetSessions", target), "weekly_streaks");
        log.info("[schedule-sync] user={} week={} thêm {} buổi, bỏ {} buổi, đổi giờ {} buổi, chỉ tiêu {}", user.id(),
            weekStart, added.size(), removed.size(), retimed.size(), target);
    }

    private List<Exercise> safeExercises(User user, ObjectId userId) {
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
