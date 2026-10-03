package vn.levelup.jobs;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Map;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;

import vn.levelup.common.LocalDates;
import vn.levelup.motivation.CoachTemplates;
import vn.levelup.motivation.ReengagementRules;
import vn.levelup.notifications.NotificationGateway;
import vn.levelup.plans.TrainingPlan;

/**
 * F3: chốt ngày cho một người dùng. Buổi đã qua còn planned và chưa có log → skipped,
 * cập nhật users.reengagement, vào missed_2 thì coach hỏi lý do, lapsed thì nhắc quay lại.
 * Chạy lại an toàn: chỉ buổi còn planned mới bị đổi, chỉ lần đổi bậc mới tạo tin, thông báo có dedupeKey.
 */
@Service
public class DailyCloseService {

    private static final Logger log = LoggerFactory.getLogger(DailyCloseService.class);
    static final List<Map<String, String>> SKIP_REASONS = List.of(
        Map.of("reason", "busy", "label", "Bận"), Map.of("reason", "tired", "label", "Mệt"),
        Map.of("reason", "pain", "label", "Đau"), Map.of("reason", "bored", "label", "Chán"),
        Map.of("reason", "forgot", "label", "Quên"));

    private final MongoTemplate mongo;
    private final NotificationGateway notifications;
    private final CoachTemplates templates;
    private final Clock clock;

    public DailyCloseService(MongoTemplate mongo, NotificationGateway notifications, CoachTemplates templates,
                             Clock clock) {
        this.mongo = mongo;
        this.notifications = notifications;
        this.templates = templates;
        this.clock = clock;
    }

    /** skipped: số buổi vừa chuyển sang skipped; notified: type thông báo đã gửi hoặc lưu. */
    public record DayResult(int skipped, String stageBefore, String stageAfter, List<String> notified) {}

    /** Chốt mọi buổi planned có scheduledDate từ ngày này trở về trước (bù cả ngày job không chạy). */
    public DayResult closeDay(ObjectId userId, LocalDate date) {
        List<TrainingPlan> plans = mongo.find(Query.query(Criteria.where("userId").is(userId)
            .and("status").is("active").and("sessions").elemMatch(Criteria.where("status").is("planned")
                .and("scheduledDate").lte(date.toString()))), TrainingPlan.class);
        List<ObjectId> due = new ArrayList<>();
        for (TrainingPlan plan : plans) {
            plan.sessions().stream()
                .filter(s -> "planned".equals(s.status()) && s.scheduledDate().compareTo(date.toString()) <= 0)
                .filter(s -> !mongo.exists(Query.query(Criteria.where("userId").is(userId)
                    .and("plannedSessionId").is(s.id())), "workout_logs"))
                .forEach(s -> due.add(s.id()));
        }
        return skipSessions(userId, due);
    }

    /** Đánh dấu các buổi này skipped (nếu còn planned) rồi cập nhật bậc nhắc. Demo dùng trực tiếp. */
    public DayResult skipSessions(ObjectId userId, List<ObjectId> sessionIds) {
        int skipped = 0;
        ObjectId lastSkipped = null;
        for (ObjectId sessionId : sessionIds) {
            var result = mongo.updateFirst(Query.query(Criteria.where("userId").is(userId).and("status").is("active")
                    .and("sessions").elemMatch(Criteria.where("_id").is(sessionId).and("status").is("planned"))),
                Update.update("sessions.$.status", "skipped"), TrainingPlan.class);
            if (result.getModifiedCount() > 0) {
                skipped++;
                lastSkipped = sessionId;
            }
        }
        return applyMisses(userId, skipped, lastSkipped);
    }

    private DayResult applyMisses(ObjectId userId, int skipped, ObjectId lastSkipped) {
        Document user = mongo.findById(userId, Document.class, "users");
        if (user == null) {
            return new DayResult(skipped, null, null, List.of());
        }
        Instant now = clock.instant();
        Document re = user.get("reengagement", new Document());
        String before = re.getString("stage") == null ? "active" : re.getString("stage");
        int missed = number(re.get("consecutiveMissed")) + skipped;
        Date since = re.getDate("lastWorkoutAt") != null ? re.getDate("lastWorkoutAt") : user.getDate("createdAt");
        long days = since == null ? 0 : Duration.between(since.toInstant(), now).toDays();
        String after = ReengagementRules.next(before, missed, days);
        int messagesInStage = number(re.get("messagesInStage"));

        boolean changed = !after.equals(before);
        if (skipped > 0 || changed) {
            // Điều kiện stage cũ: hai lần chốt song song thì chỉ một lần được đổi bậc và tạo tin
            Criteria sameStage = "active".equals(before) && re.getString("stage") == null
                ? Criteria.where("reengagement.stage").exists(false) : Criteria.where("reengagement.stage").is(before);
            Update update = new Update().inc("reengagement.consecutiveMissed", skipped)
                .set("reengagement.stage", after);
            if (changed) {
                update.set("reengagement.stageEnteredAt", Date.from(now)).set("reengagement.messagesInStage", 0);
                messagesInStage = 0;
            }
            var result = mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)).addCriteria(sameStage),
                update, "users");
            if (result.getModifiedCount() == 0) {
                log.info("[daily-close] bỏ qua user={}: reengagement vừa đổi ở nơi khác", userId);
                return new DayResult(skipped, before, before, List.of());
            }
        }

        List<String> notified = new ArrayList<>();
        String localDate = LocalDates.today(user.getString("timezone"), clock).toString();
        if (changed && "missed_2".equals(after)) {
            askReason(userId, user, lastSkipped, localDate);
            notified.add("missed_2");
        }
        if (ReengagementRules.lapsedMessageDue(after, messagesInStage) && comeBack(userId, user, after, localDate)) {
            notified.add("lapsed");
        }
        return new DayResult(skipped, before, after, notified);
    }

    /** Vào missed_2: tin coach kèm thẻ 5 lý do, rồi thông báo qua cổng gửi. */
    private void askReason(ObjectId userId, Document user, ObjectId sessionId, String localDate) {
        Map<String, String> vars = Map.of("ten", name(user));
        String text = templates.render("missed_2", coachStyle(user), vars, localDate)
            .orElse(name(user) + ", điều gì cản trở hai buổi vừa rồi? Chọn: Bận, Mệt, Đau, Chán, Quên.");
        ObjectId messageId = new ObjectId();
        Document message = new Document("_id", messageId)
            .append("userId", userId)
            .append("role", "coach")
            .append("content", text)
            .append("card", new Document("type", "skip_reasons").append("status", "proposed")
                .append("options", SKIP_REASONS.stream().map(Document::new).toList()))
            .append("trigger", "missed_2")
            .append("createdAt", Date.from(clock.instant()));
        if (sessionId != null) {
            message.append("relatedSessionId", sessionId);
        }
        mongo.insert(message, "coach_messages");
        notifications.send(userId, "missed_2", "LevelUp", text, userId.toHexString() + "|" + localDate + "|missed_2",
            Map.of("route", "/coach", "coachMessageId", messageId.toHexString()));
    }

    /**
     * Tin quay lại cho lapsed_7 / lapsed_14. dedupeKey theo tuần: lapsed_14 tối đa một tin mỗi tuần.
     * TODO: tạo tuần khởi động lại nhẹ hơn (cần module plans/reviews).
     */
    private boolean comeBack(ObjectId userId, Document user, String stage, String localDate) {
        String week = LocalDates.weekStart(LocalDate.parse(localDate)).toString();
        Document profile = user.get("profile", new Document());
        String reason = profile.getString("motivationText");
        if (reason == null || reason.isBlank()) {
            reason = "sức khỏe của chính bạn";
        }
        String text = templates.render("lapsed_7", coachStyle(user), Map.of("ten", name(user), "ly_do", reason),
            localDate).orElse(name(user) + ", cửa quay lại vẫn mở. Thử một buổi 5 phút nhé.");
        NotificationGateway.Result result = notifications.send(userId, "lapsed", "LevelUp", text,
            userId.toHexString() + "|" + week + "|" + stage, Map.of("route", "/plan"));
        if (result == NotificationGateway.Result.DUPLICATE || result == NotificationGateway.Result.DAILY_LIMIT) {
            return false;
        }
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId).and("reengagement.stage").is(stage)),
            new Update().inc("reengagement.messagesInStage", 1), "users");
        return true;
    }

    private static String name(Document user) {
        String name = user.getString("displayName");
        return name == null ? "" : name;
    }

    private static String coachStyle(Document user) {
        return user.get("profile", new Document()).getString("coachStyle");
    }

    private static int number(Object value) {
        return value instanceof Number n ? n.intValue() : 0;
    }
}
