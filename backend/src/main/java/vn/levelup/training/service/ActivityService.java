package vn.levelup.training.service;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;

import vn.levelup.identity.model.User;
import vn.levelup.nutrition.rules.NutritionRules;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.ActivityDtos;

/** Lưu số bước và calo vận động hôm nay vào daily_stats.activity (một document mỗi người mỗi ngày). */
@Service
public class ActivityService {

    public static final int MAX_HISTORY_DAYS = 90;

    private final MongoTemplate mongo;
    private final Clock clock;

    public ActivityService(MongoTemplate mongo, Clock clock) {
        this.mongo = mongo;
        this.clock = clock;
    }

    /** activeKcalInWorkouts null: app chưa gửi phần trùng giờ tập (app cũ). */
    public record Activity(int steps, int activeKcal, Integer activeKcalInWorkouts) {}

    /**
     * App gửi số liệu cộng dồn từ 0h; dùng $max nên gửi lại, gửi trễ hay gửi từ điện thoại thứ hai (số nhỏ hơn)
     * không làm giảm số đã lưu.
     */
    public ActivityDtos.ActivityView save(User user, ActivityDtos.ActivityRequest r) {
        ObjectId userId = new ObjectId(user.id());
        LocalDate today = LocalDates.today(user.timezone(), clock);
        if (!today.toString().equals(r.localDate())) {
            return new ActivityDtos.ActivityView(today.toString(), 0, 0, false);
        }
        Update update = new Update()
            .max("activity.steps", r.steps())
            .max("activity.activeKcal", r.activeKcal())
            .set("activity.source", "health_connect")
            .set("activity.updatedAt", Date.from(clock.instant()))
            .setOnInsert("userId", userId).setOnInsert("localDate", today.toString());
        if (r.activeKcalInWorkouts() != null) {
            // Phần trùng giờ tập không lớn hơn tổng calo vận động máy đó đã đọc
            update.max("activity.activeKcalInWorkouts", Math.min(r.activeKcalInWorkouts(), r.activeKcal()));
        }
        mongo.upsert(day(userId, today), update, "daily_stats");
        Activity a = today(userId, today).orElse(new Activity(r.steps(), r.activeKcal(), null));
        return new ActivityDtos.ActivityView(today.toString(), a.steps(), a.activeKcal(), true);
    }

    /** Số đã lưu hôm nay và giờ các buổi tập hôm nay (app dùng để tính calo vận động trùng giờ tập). */
    public ActivityDtos.TodayView todayView(User user) {
        ObjectId userId = new ObjectId(user.id());
        LocalDate today = LocalDates.today(user.timezone(), clock);
        Activity a = today(userId, today).orElse(new Activity(0, 0, null));
        List<ActivityDtos.WorkoutWindow> windows = new ArrayList<>();
        for (Document w : mongo.find(day(userId, today).with(Sort.by("startedAt")), Document.class, "workout_logs")) {
            Date started = w.getDate("startedAt");
            if (started == null) {
                continue;
            }
            Date ended = w.getDate("endedAt");
            Instant end = ended != null ? ended.toInstant()
                : started.toInstant().plusSeconds(w.get("durationSec") instanceof Number n ? n.longValue() : 0);
            windows.add(new ActivityDtos.WorkoutWindow(started.toInstant(), end));
        }
        return new ActivityDtos.TodayView(today.toString(), a.steps(), a.activeKcal(), windows);
    }

    /** [days] ngày gần nhất tính tới hôm nay của người dùng (1–90), từ cũ tới mới. */
    public ActivityDtos.HistoryView history(User user, int days) {
        ObjectId userId = new ObjectId(user.id());
        LocalDate today = LocalDates.today(user.timezone(), clock);
        LocalDate from = today.minusDays(Math.max(1, Math.min(days, MAX_HISTORY_DAYS)) - 1L);
        Map<String, Activity> activity = new HashMap<>();
        for (Document d : mongo.find(range(userId, from, today), Document.class, "daily_stats")) {
            activity(d).ifPresent(a -> activity.put(d.getString("localDate"), a));
        }
        Map<String, Integer> workout = new HashMap<>();
        Query workouts = range(userId, from, today);
        workouts.fields().include("localDate").include("kcalBurned");
        for (Document w : mongo.find(workouts, Document.class, "workout_logs")) {
            workout.merge(w.getString("localDate"), num(w.get("kcalBurned")), Integer::sum);
        }
        List<ActivityDtos.DayView> result = new ArrayList<>();
        for (LocalDate d = from; !d.isAfter(today); d = d.plusDays(1)) {
            Activity a = activity.getOrDefault(d.toString(), new Activity(0, 0, null));
            int w = workout.getOrDefault(d.toString(), 0);
            result.add(new ActivityDtos.DayView(d.toString(), a.steps(), a.activeKcal(), w,
                NutritionRules.totalBurnedKcal(w, a.activeKcal(), a.activeKcalInWorkouts())));
        }
        return new ActivityDtos.HistoryView(result);
    }

    /** Tổng calo đốt ước tính của các buổi tập trong ngày (workout_logs.kcalBurned). */
    public int workoutKcal(ObjectId userId, LocalDate day) {
        Query q = day(userId, day);
        q.fields().include("kcalBurned");
        return mongo.find(q, Document.class, "workout_logs").stream().mapToInt(d -> num(d.get("kcalBurned"))).sum();
    }

    public Optional<Activity> today(ObjectId userId, LocalDate day) {
        return today(mongo, userId, day);
    }

    /** Dùng chung với CoachService (giống CheckinService.today). */
    public static Optional<Activity> today(MongoTemplate mongo, ObjectId userId, LocalDate day) {
        Document d = mongo.findOne(day(userId, day), Document.class, "daily_stats");
        return d == null ? Optional.empty() : activity(d);
    }

    private static Optional<Activity> activity(Document dailyStats) {
        if (!(dailyStats.get("activity") instanceof Document a)) {
            return Optional.empty();
        }
        return Optional.of(new Activity(num(a.get("steps")), num(a.get("activeKcal")),
            a.get("activeKcalInWorkouts") instanceof Number n ? n.intValue() : null));
    }

    private static Query day(ObjectId userId, LocalDate day) {
        return Query.query(Criteria.where("userId").is(userId).and("localDate").is(day.toString()));
    }

    private static Query range(ObjectId userId, LocalDate from, LocalDate to) {
        return Query.query(Criteria.where("userId").is(userId).and("localDate").gte(from.toString())
            .lte(to.toString()));
    }

    private static int num(Object o) {
        return o instanceof Number n ? n.intValue() : 0;
    }
}
