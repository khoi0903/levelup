package vn.levelup.engagement.service;

import java.time.Clock;
import java.time.LocalDate;
import java.util.Date;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;
import vn.levelup.engagement.rules.WeekCloseRules;
import vn.levelup.training.model.TrainingPlan;


/**
 * F4: chốt tuần cho một người dùng theo flowchart "Chốt tuần". Chạy lại an toàn: tuần đã có closedAt
 * thì không làm gì; việc "nhận" tuần để chốt là một lệnh update có điều kiện closedAt chưa có.
 * Streak chung của buddy tính trong buddies/BuddyWeekListener (một WeekClosedListener).
 */
@Service
public class WeekCloseService {

    private static final Logger log = LoggerFactory.getLogger(WeekCloseService.class);
    static final int DEFAULT_TARGET = 3;
    private static final int RUN_LOOKBACK_WEEKS = 52;

    private final MongoTemplate mongo;
    private final WeekCloseListeners listeners;
    private final Clock clock;

    public WeekCloseService(MongoTemplate mongo, WeekCloseListeners listeners, Clock clock) {
        this.mongo = mongo;
        this.listeners = listeners;
        this.clock = clock;
    }

    /** closed = false khi tuần không có dữ liệu hoặc đã chốt trước đó. */
    public record WeekResult(String weekStart, boolean closed, String status, Integer currentWeeks,
                             List<String> newAchievements) {}

    public WeekResult closeWeek(ObjectId userId, LocalDate weekStart) {
        String week = weekStart.toString();
        Query thisWeek = Query.query(Criteria.where("userId").is(userId).and("weekStart").is(week));
        Document doc = mongo.findOne(thisWeek, Document.class, "weekly_streaks");
        Document user = mongo.findById(userId, Document.class, "users");
        if (doc == null || user == null) {
            return new WeekResult(week, false, null, null, List.of());
        }
        if (doc.get("closedAt") != null) {
            return new WeekResult(week, false, doc.getString("status"), null, List.of());
        }

        Document streak = user.get("streak", new Document());
        Set<String> owned = user.getList("achievements", Document.class, List.of()).stream()
            .map(a -> a.getString("code")).collect(Collectors.toSet());
        int target = number(doc.get("targetSessions"));
        WeekCloseRules.Decision d = WeekCloseRules.decide(doc.getString("status"),
            number(doc.get("completedSessions")), target, number(streak.get("freezesAvailable")),
            number(streak.get("currentWeeks")), number(streak.get("bestWeeks")),
            achievedRunBefore(userId, weekStart), owned);

        Date now = Date.from(clock.instant());
        Update closeUpdate = new Update().set("status", d.status()).set("closedAt", now);
        if (d.freezeEvent() != null) {
            closeUpdate.set("freezeEvent", d.freezeEvent());
        }
        var claimed = mongo.updateFirst(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(week)
            .and("closedAt").exists(false)), closeUpdate, "weekly_streaks");
        if (claimed.getModifiedCount() == 0) {
            return new WeekResult(week, false, doc.getString("status"), null, List.of());
        }

        Update userUpdate = new Update()
            .set("streak.currentWeeks", d.currentWeeks())
            .set("streak.bestWeeks", d.bestWeeks())
            .set("streak.freezesAvailable", d.freezesAvailable())
            .set("streak.lastClosedWeek", week);
        if (!d.newAchievements().isEmpty()) {
            userUpdate.push("achievements").each(d.newAchievements().stream().map(code -> new Document("code", code)
                .append("earnedAt", now).append("context", new Document("weekStart", week))).toArray());
        }
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)), userUpdate, "users");

        // Tuần sau: mục tiêu theo kế hoạch active tuần sau, chưa có thì giữ mục tiêu tuần này
        String nextWeek = weekStart.plusWeeks(1).toString();
        TrainingPlan nextPlan = mongo.findOne(Query.query(Criteria.where("userId").is(userId)
            .and("weekStart").is(nextWeek).and("status").is("active")), TrainingPlan.class);
        int nextTarget = nextPlan != null && nextPlan.targetSessions() != null ? nextPlan.targetSessions()
            : (target > 0 ? target : DEFAULT_TARGET);
        mongo.upsert(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(nextWeek)),
            new Update().setOnInsert("targetSessions", nextTarget).setOnInsert("completedSessions", 0)
                .setOnInsert("status", "in_progress"), "weekly_streaks");

        listeners.weekClosed(userId, week);
        log.info("[week-close] user={} week={} status={} streak={}", userId, week, d.status(), d.currentWeeks());
        return new WeekResult(week, true, d.status(), d.currentWeeks(), d.newAchievements());
    }

    /** Số tuần achieved liên tiếp ngay trước tuần này (tuần thiếu dữ liệu hoặc không achieved làm đứt chuỗi). */
    private int achievedRunBefore(ObjectId userId, LocalDate weekStart) {
        List<Document> weeks = mongo.find(Query.query(Criteria.where("userId").is(userId)
                .and("weekStart").lt(weekStart.toString())
                .gte(weekStart.minusWeeks(RUN_LOOKBACK_WEEKS).toString()))
            .with(Sort.by(Sort.Direction.DESC, "weekStart")), Document.class, "weekly_streaks");
        int run = 0;
        LocalDate expected = weekStart.minusWeeks(1);
        for (Document w : weeks) {
            if (!expected.toString().equals(w.getString("weekStart")) || !"achieved".equals(w.getString("status"))) {
                break;
            }
            run++;
            expected = expected.minusWeeks(1);
        }
        return run;
    }

    private static int number(Object value) {
        return value instanceof Number n ? n.intValue() : 0;
    }
}
