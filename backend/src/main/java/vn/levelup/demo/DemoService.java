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
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;

import vn.levelup.common.LocalDates;
import vn.levelup.exercises.Exercise;
import vn.levelup.exercises.ExerciseRepository;
import vn.levelup.jobs.DailyCloseService;
import vn.levelup.jobs.WeekCloseService;
import vn.levelup.motivation.WeekCloseListeners;
import vn.levelup.plans.PlanReader;
import vn.levelup.plans.TrainingPlan;
import vn.levelup.users.User;

/** Nút giả lập: gọi đúng hàm job thật dùng, chỉ bỏ qua điều kiện giờ giấc. */
@Service
public class DemoService {

    static final int SEED_WEEKS = 4;
    static final int SEED_TARGET = 3;
    static final int SEED_MINUTES = 20;
    /** Dữ liệu demo bị xóa trước khi seed lại. Kế hoạch tập (training_plans) được giữ. */
    static final List<String> GENERATED = List.of("workout_logs", "weekly_streaks", "personal_records",
        "skip_reports", "notifications", "coach_messages", "daily_stats");

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final PlanReader plans;
    private final DailyCloseService dailyClose;
    private final WeekCloseService weekClose;
    private final WeekCloseListeners listeners;
    private final Clock clock;

    public DemoService(MongoTemplate mongo, ExerciseRepository exercises, PlanReader plans,
                       DailyCloseService dailyClose, WeekCloseService weekClose, WeekCloseListeners listeners,
                       Clock clock) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.plans = plans;
        this.dailyClose = dailyClose;
        this.weekClose = weekClose;
        this.listeners = listeners;
        this.clock = clock;
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

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("weeks", SEED_WEEKS);
        result.put("workouts", logs.size());
        result.put("currentWeeks", 3);
        result.put("personalRecordExerciseId", exerciseId.toHexString());
        return result;
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
