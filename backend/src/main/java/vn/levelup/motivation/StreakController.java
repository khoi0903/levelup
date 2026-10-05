package vn.levelup.motivation;

import java.time.Clock;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import vn.levelup.auth.CurrentUserService;
import vn.levelup.common.LocalDates;
import vn.levelup.plans.TrainingPlan;
import vn.levelup.users.User;

@RestController
public class StreakController {

    static final int HISTORY_WEEKS = 8;
    /** Đủ để đếm streak dài; streak hơn một năm thì job chốt tuần giữ trong users.streak.bestWeeks. */
    private static final int LOOKBACK_WEEKS = 60;

    private final MongoTemplate mongo;
    private final CurrentUserService currentUser;
    private final Clock clock;

    public StreakController(MongoTemplate mongo, CurrentUserService currentUser, Clock clock) {
        this.mongo = mongo;
        this.currentUser = currentUser;
        this.clock = clock;
    }

    /** F4: streak hiện tại, kỷ lục, thẻ đóng băng, 8 tuần gần nhất (cũ trước mới sau). */
    @GetMapping("/streak")
    public StreakView streak() {
        User user = currentUser.require();
        ObjectId userId = new ObjectId(user.id());
        LocalDate thisWeek = LocalDates.weekStart(LocalDates.today(user.timezone(), clock));

        List<StreakCalculator.Week> weeks = mongo.find(Query.query(Criteria.where("userId").is(userId)
                    .and("weekStart").gte(thisWeek.minusWeeks(LOOKBACK_WEEKS).toString()))
                .with(Sort.by(Sort.Direction.DESC, "weekStart")), Document.class, "weekly_streaks")
            .stream()
            .map(d -> new StreakCalculator.Week(d.getString("weekStart"), number(d, "targetSessions"),
                number(d, "completedSessions"), d.getString("status")))
            .toList();

        int current = StreakCalculator.currentWeeks(weeks, thisWeek);
        User.Streak stored = user.streak();
        int best = Math.max(current, stored == null || stored.bestWeeks() == null ? 0 : stored.bestWeeks());
        int freezes = stored == null || stored.freezesAvailable() == null ? 0 : stored.freezesAvailable();
        List<StreakCalculator.Week> history = StreakCalculator.fromFirstActive(
            StreakCalculator.lastWeeks(weeks, thisWeek, HISTORY_WEEKS));
        return new StreakView(current, best, freezes, history.getLast(), history);
    }

    /**
     * Chi tiết một tuần (bấm vào tuần trong lịch sử streak): 7 ngày từ Thứ Hai, mỗi ngày gồm buổi trong kế hoạch
     * và buổi đã tập. Ngày bất kỳ trong tuần cũng được, tự đưa về Thứ Hai. Chỉ dữ liệu của người đang đăng nhập.
     */
    @GetMapping("/streak/weeks/{date}")
    public WeekDetail week(@PathVariable String date) {
        User user = currentUser.require();
        ObjectId userId = new ObjectId(user.id());
        LocalDate weekStart;
        try {
            weekStart = LocalDates.weekStart(LocalDate.parse(date));
        } catch (DateTimeParseException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_DATE");
        }
        String week = weekStart.toString();

        Document streak = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(week)),
            Document.class, "weekly_streaks");
        List<TrainingPlan.Session> sessions = mongo.find(Query.query(Criteria.where("userId").is(userId)
                .and("weekStart").is(week).and("status").in("active", "completed")), TrainingPlan.class)
            .stream().flatMap(p -> p.sessions() == null ? Stream.empty() : p.sessions().stream()).toList();
        List<Document> logs = mongo.find(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(week))
            .with(Sort.by("startedAt")), Document.class, "workout_logs");

        List<Day> days = new ArrayList<>();
        for (int i = 0; i < 7; i++) {
            String day = weekStart.plusDays(i).toString();
            days.add(new Day(day, i + 1,
                sessions.stream().filter(s -> day.equals(s.scheduledDate()))
                    .sorted(Comparator.comparing(s -> s.scheduledTime() == null ? "" : s.scheduledTime()))
                    .map(s -> new DaySession(s.id().toHexString(), s.title(), s.scheduledTime(), s.durationMin(),
                        s.status()))
                    .toList(),
                logs.stream().filter(l -> day.equals(l.getString("localDate")))
                    .map(l -> new DayWorkout(l.getObjectId("_id").toHexString(),
                        l.getDate("startedAt") == null ? null : l.getDate("startedAt").toInstant().toString(),
                        l.get("durationSec") instanceof Number n ? (int) Math.round(n.doubleValue() / 60) : 0,
                        Boolean.TRUE.equals(l.getBoolean("countsForStreak")),
                        l.get("plannedSessionId") instanceof ObjectId id ? id.toHexString() : null))
                    .toList()));
        }
        return new WeekDetail(week, streak == null ? "none" : streak.getString("status"),
            streak == null ? 0 : number(streak, "targetSessions"), streak == null ? 0 : number(streak, "completedSessions"),
            days);
    }

    public record WeekDetail(String weekStart, String status, int targetSessions, int completedSessions,
                             List<Day> days) {}

    /** weekday: 1 = Thứ Hai … 7 = Chủ nhật. */
    public record Day(String date, int weekday, List<DaySession> sessions, List<DayWorkout> workouts) {}

    public record DaySession(String id, String title, String scheduledTime, Integer durationMin, String status) {}

    /** plannedSessionId null: buổi tập thêm (không gắn lịch). */
    public record DayWorkout(String id, String startedAt, int durationMin, boolean countsForStreak,
                             String plannedSessionId) {}

    private static int number(Document d, String key) {
        Object v = d.get(key);
        return v instanceof Number n ? n.intValue() : 0;
    }

    public record StreakView(int currentWeeks, int bestWeeks, int freezesAvailable,
                             StreakCalculator.Week thisWeek, List<StreakCalculator.Week> weeks) {}
}
