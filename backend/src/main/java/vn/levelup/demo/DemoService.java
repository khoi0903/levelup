package vn.levelup.demo;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;
import vn.levelup.engagement.notification.NotificationGateway;
import vn.levelup.engagement.service.DailyCloseService;
import vn.levelup.engagement.service.WeekCloseListeners;
import vn.levelup.engagement.service.WeekCloseService;
import vn.levelup.identity.model.User;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.repository.ExerciseRepository;
import vn.levelup.training.service.PlanReader;


/** Nút giả lập: gọi đúng hàm job thật dùng, chỉ bỏ qua điều kiện giờ giấc. */
@Service
public class DemoService {

    static final int SEED_WEEKS = 4;
    static final int SEED_TARGET = 3;
    static final int SEED_MINUTES = 20;
    /** Dữ liệu demo bị xóa trước khi seed lại. Kế hoạch tập (training_plans) được giữ. */
    static final List<String> GENERATED = List.of("workout_logs", "weekly_streaks", "personal_records",
        "skip_reports", "notifications", "coach_messages", "daily_stats", "body_measurements", "meal_logs");
    /** Số ngày có bữa ăn mẫu (mỗi ngày sáng, trưa, tối), không tính hôm nay để demo ghi bữa mới. */
    static final int SEED_MEAL_DAYS = 7;
    static final String[] MEALS = {"breakfast", "lunch", "dinner"};

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final PlanReader plans;
    private final DailyCloseService dailyClose;
    private final WeekCloseService weekClose;
    private final WeekCloseListeners listeners;
    private final NotificationGateway notifications;
    private final Clock clock;

    public DemoService(MongoTemplate mongo, ExerciseRepository exercises, PlanReader plans,
                       DailyCloseService dailyClose, WeekCloseService weekClose, WeekCloseListeners listeners,
                       NotificationGateway notifications, Clock clock) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.plans = plans;
        this.dailyClose = dailyClose;
        this.weekClose = weekClose;
        this.listeners = listeners;
        this.notifications = notifications;
        this.clock = clock;
    }

    /** Gửi nhắc check-in sáng ngay (job thật chỉ gửi trong khung giờ check-in). Đi qua cổng gửi thật. */
    public Map<String, Object> checkin(User user) {
        String name = user.displayName() == null ? "" : user.displayName();
        return push(user, "checkin_morning",
            name + ", hôm nay bạn thấy thế nào? Check-in để mình chỉnh buổi tập cho vừa sức nhé.", "/checkin");
    }

    /** Thông báo thử: kiểm tra điện thoại nhận được push (token, quyền, FCM). */
    public Map<String, Object> pushTest(User user) {
        return push(user, "demo_test", "Thông báo thử từ LevelUp: điện thoại đã nhận được thông báo đẩy.", "/home");
    }

    private Map<String, Object> push(User user, String type, String body, String route) {
        NotificationGateway.Result r = notifications.send(new ObjectId(user.id()), type, "LevelUp", body,
            "demo|" + user.id() + "|" + type + "|" + clock.instant().toEpochMilli(), Map.of("route", route));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("type", type);
        result.put("result", r.name());      // SENT | STORED_ONLY (chưa có thiết bị) | QUIET_HOURS | DAILY_LIMIT
        return result;
    }

    /** Đánh dấu 2 buổi planned gần nhất (tới hôm nay) là skipped rồi chạy phần còn lại của chốt ngày. */
    public Map<String, Object> skipTwo(User user) {
        ObjectId userId = new ObjectId(user.id());
        String today = LocalDates.today(user.timezone(), clock).toString();
        List<TrainingPlan.Session> past = new ArrayList<>();
        mongo.find(Query.query(Criteria.where("userId").is(userId).and("status").is("active")), TrainingPlan.class)
            .forEach(p -> p.sessions().stream()
                .filter(s -> "planned".equals(s.status()) && s.scheduledDate().compareTo(today) <= 0)
                .forEach(past::add));
        List<ObjectId> ids = past.stream()
            .sorted(Comparator.comparing(TrainingPlan.Session::scheduledDate)
                .thenComparing(s -> s.scheduledTime() == null ? "" : s.scheduledTime()).reversed())
            .limit(2)
            .map(TrainingPlan.Session::id)
            .toList();
        DailyCloseService.DayResult r = dailyClose.skipSessions(userId, ids);
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("skipped", r.skipped());
        result.put("stageBefore", r.stageBefore());
        result.put("stageAfter", r.stageAfter());
        result.put("notified", r.notified());
        return result;
    }

    public Map<String, Object> closeWeek(User user) {
        WeekCloseService.WeekResult r = weekClose.closeWeek(new ObjectId(user.id()), thisWeek(user));
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("weekStart", r.weekStart());
        result.put("closed", r.closed());
        result.put("status", r.status());
        result.put("currentWeeks", r.currentWeeks());
        result.put("newAchievements", r.newAchievements());
        return result;
    }

    public Map<String, Object> review(User user) {
        String week = thisWeek(user).toString();
        return Map.of("weekStart", week, "listeners", listeners.weekClosed(new ObjectId(user.id()), week));
    }

    /**
     * Lịch sử demo: 4 tuần trước (3 tuần gần nhất đạt), 9 buổi tập, 1 kỷ lục mới, streak 3 tuần.
     * Xóa dữ liệu sinh ra của người dùng này trước, nên chạy lại cho cùng kết quả.
     */
    public Map<String, Object> seed(User user) {
        ObjectId userId = new ObjectId(user.id());
        ZoneId zone = LocalDates.zone(user.timezone());
        LocalDate thisWeek = thisWeek(user);
        Instant now = clock.instant();
        for (String collection : GENERATED) {
            mongo.remove(Query.query(Criteria.where("userId").is(userId)), collection);
        }

        TrainingPlan plan = plans.current(userId, LocalDates.today(user.timezone(), clock));
        ObjectId exerciseId = pickExercise(plan);

        List<Document> logs = new ArrayList<>();
        int n = 0;
        int lastWeekIndex = SEED_WEEKS - 1;
        for (int i = SEED_WEEKS; i >= 1; i--) {
            LocalDate weekStart = thisWeek.minusWeeks(i);
            boolean achieved = i < SEED_WEEKS;
            mongo.insert(new Document("userId", userId).append("weekStart", weekStart.toString())
                .append("targetSessions", SEED_TARGET).append("completedSessions", achieved ? SEED_TARGET : 0)
                .append("status", achieved ? "achieved" : "missed")
                .append("closedAt", Date.from(weekStart.plusDays(6).atTime(19, 0).atZone(zone).toInstant())),
                "weekly_streaks");
            if (!achieved) {
                continue;
            }
            for (int day : new int[] {0, 2, 4}) {
                n++;
                boolean last = n == SEED_TARGET * lastWeekIndex;
                LocalDate date = weekStart.plusDays(day);
                Instant start = date.atTime(18, 30).atZone(zone).toInstant();
                logs.add(log(userId, n, date, weekStart, start, exerciseId, last ? 12 : 10, last, now));
            }
        }
        mongo.insert(logs, "workout_logs");
        Document lastLog = logs.getLast();
        mongo.insert(new Document("userId", userId).append("exerciseId", exerciseId).append("metric", "max_reps")
            .append("value", 12.0).append("workoutLogId", lastLog.getObjectId("_id"))
            .append("achievedAt", lastLog.getDate("endedAt")), "personal_records");

        int target = plan != null && thisWeek.toString().equals(plan.weekStart()) && plan.targetSessions() != null
            ? plan.targetSessions() : SEED_TARGET;
        mongo.insert(new Document("userId", userId).append("weekStart", thisWeek.toString())
            .append("targetSessions", target).append("completedSessions", 0).append("status", "in_progress"),
            "weekly_streaks");

        String lastClosed = thisWeek.minusWeeks(1).toString();
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)), new Update()
            .set("streak", new Document("currentWeeks", 3).append("bestWeeks", 3).append("freezesAvailable", 0)
                .append("lastClosedWeek", lastClosed))
            .set("reengagement", new Document("stage", "active").append("lastWorkoutAt", lastLog.getDate("endedAt"))
                .append("consecutiveMissed", 0).append("messagesInStage", 0))
            .set("achievements", List.of(
                new Document("code", "sessions_1").append("earnedAt", logs.getFirst().getDate("endedAt")),
                new Document("code", "streak_2").append("earnedAt", Date.from(now))
                    .append("context", new Document("weekStart", thisWeek.minusWeeks(2).toString())))),
            "users");

        int measurements = seedMeasurements(user, userId, now);
        int meals = seedMeals(user, userId, zone, now);
        // Demo bấm nhiều nút gửi thông báo: nới giới hạn mỗi ngày (giờ yên lặng giữ nguyên)
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)),
            Update.update("notificationSettings.maxPerDay", 5), "users");

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("weeks", SEED_WEEKS);
        result.put("measurements", measurements);
        result.put("meals", meals);
        result.put("workouts", logs.size());
        result.put("currentWeeks", 3);
        result.put("personalRecordExerciseId", exerciseId.toHexString());
        return result;
    }

    /** Cân nặng mỗi tuần trong 4 tuần trước, giảm dần 0,5 kg/tuần về cân nặng lúc onboarding. */
    private int seedMeasurements(User user, ObjectId userId, Instant now) {
        double start = user.profile() != null && user.profile().startWeightKg() != null
            ? user.profile().startWeightKg() : 70.0;
        LocalDate today = LocalDates.today(user.timezone(), clock);
        List<Document> docs = new ArrayList<>();
        for (int i = SEED_WEEKS; i >= 1; i--) {
            docs.add(new Document("userId", userId).append("measuredOn", today.minusWeeks(i).toString())
                .append("weightKg", start + 0.5 * i).append("source", "demo").append("createdAt", Date.from(now)));
        }
        mongo.insert(docs, "body_measurements");
        return docs.size();
    }

    /** Sáng, trưa, tối trong 7 ngày trước hôm nay, lấy món trong kho foods (xoay vòng cho đa dạng). */
    private int seedMeals(User user, ObjectId userId, ZoneId zone, Instant now) {
        List<Document> foods = mongo.find(Query.query(Criteria.where("source").is("curated"))
            .with(Sort.by("searchName")), Document.class, "foods");
        if (foods.isEmpty()) {
            return 0;
        }
        LocalDate today = LocalDates.today(user.timezone(), clock);
        int[] hours = {7, 12, 19};
        List<Document> docs = new ArrayList<>();
        for (int d = SEED_MEAL_DAYS; d >= 1; d--) {
            LocalDate date = today.minusDays(d);
            for (int m = 0; m < MEALS.length; m++) {
                Document f = foods.get((d * 7 + m * 13) % foods.size());
                double kcal = number(f, "kcal");
                Document item = new Document("foodId", f.getObjectId("_id")).append("name", f.getString("nameVi"))
                    .append("quantity", 1.0).append("unit", "phần").append("kcal", kcal)
                    .append("proteinG", number(f, "proteinG")).append("carbsG", number(f, "carbsG"))
                    .append("fatG", number(f, "fatG"));
                docs.add(new Document("userId", userId).append("localDate", date.toString())
                    .append("eatenAt", Date.from(date.atTime(hours[m], 0).atZone(zone).toInstant()))
                    .append("meal", MEALS[m]).append("method", "search").append("kcal", kcal)
                    .append("proteinG", number(f, "proteinG")).append("carbsG", number(f, "carbsG"))
                    .append("fatG", number(f, "fatG")).append("items", List.of(item))
                    .append("createdAt", Date.from(now)));
            }
        }
        mongo.insert(docs, "meal_logs");
        return docs.size();
    }

    private static double number(Document d, String key) {
        return d.get(key) instanceof Number n ? n.doubleValue() : 0.0;
    }

    private Document log(ObjectId userId, int n, LocalDate date, LocalDate weekStart, Instant start,
                         ObjectId exerciseId, int reps, boolean pr, Instant now) {
        Instant end = start.plusSeconds(SEED_MINUTES * 60L);
        List<Document> sets = new ArrayList<>();
        for (int s = 1; s <= 2; s++) {
            sets.add(new Document("exerciseId", exerciseId).append("setIndex", s).append("reps", s == 1 ? reps : 10)
                .append("isPr", pr && s == 1).append("loggedAt", Date.from(end)).append("repSource", "manual"));
        }
        List<Document> records = pr ? List.of(new Document("exerciseId", exerciseId.toHexString())
            .append("metric", "max_reps").append("value", (double) reps).append("previous", 10.0)) : List.of();
        return new Document("_id", new ObjectId())
            .append("userId", userId)
            .append("clientId", "demo-seed-" + n)
            .append("startedAt", Date.from(start))
            .append("endedAt", Date.from(end))
            .append("localDate", date.toString())
            .append("weekStart", weekStart.toString())
            .append("durationSec", SEED_MINUTES * 60L)
            .append("variant", "normal")
            .append("countsForStreak", true)
            .append("rpe", 6)
            .append("sets", sets)
            .append("newRecords", records)
            .append("createdAt", Date.from(now));
    }

    /** Bài tính theo số lần trong kế hoạch hiện tại, không có thì bài tính theo số lần bất kỳ. */
    private ObjectId pickExercise(TrainingPlan plan) {
        List<Exercise> active = exercises.findByIsActiveTrue();
        Set<String> inPlan = plan == null ? Set.of() : plan.sessions().stream()
            .flatMap(s -> s.items() == null ? java.util.stream.Stream.empty() : s.items().stream())
            .map(i -> i.exerciseId().toHexString())
            .collect(java.util.stream.Collectors.toSet());
        return active.stream()
            .filter(e -> !"duration".equals(e.tracking()))
            .sorted(Comparator.comparing((Exercise e) -> !inPlan.contains(e.id())).thenComparing(Exercise::id))
            .map(e -> new ObjectId(e.id()))
            .findFirst()
            .orElseThrow(() -> new IllegalStateException("Chưa có bài tập trong DB, chạy mongo/load-seed.js"));
    }

    private LocalDate thisWeek(User user) {
        return LocalDates.weekStart(LocalDates.today(user.timezone(), clock));
    }
}
