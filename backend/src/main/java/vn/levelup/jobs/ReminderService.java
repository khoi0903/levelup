package vn.levelup.jobs;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Service;

import vn.levelup.motivation.CoachTemplates;
import vn.levelup.notifications.NotificationGateway;

/**
 * Nhắc check-in buổi sáng (F2) và nhắc trước buổi tập, chạy trong /jobs/tick.
 * Giờ yên lặng, tối đa tin/ngày và chống trùng do NotificationGateway lo (dedupeKey theo ngày / theo buổi).
 */
@Service
public class ReminderService {

    private final MongoTemplate mongo;
    private final NotificationGateway notifications;
    private final CoachTemplates templates;

    public ReminderService(MongoTemplate mongo, NotificationGateway notifications, CoachTemplates templates) {
        this.mongo = mongo;
        this.notifications = notifications;
        this.templates = templates;
    }

    /** @return số thông báo thực sự gửi đi (SENT) */
    public int remind(ObjectId userId, LocalDateTime local) {
        Document user = mongo.findById(userId, Document.class, "users");
        if (user == null || user.get("profile") == null) {
            return 0;                                   // chưa onboarding
        }
        Document settings = user.get("notificationSettings", new Document());
        if (Boolean.FALSE.equals(settings.getBoolean("pushEnabled"))) {
            return 0;
        }
        String date = local.toLocalDate().toString();
        int sent = 0;
        if (checkin(userId, user, settings, local, date)) {
            sent++;
        }
        if (preWorkout(userId, user, settings, local, date)) {
            sent++;
        }
        return sent;
    }

    private boolean checkin(ObjectId userId, Document user, Document settings, LocalDateTime local, String date) {
        LocalTime at = ReminderRules.time(settings.getString("checkinTime"), ReminderRules.DEFAULT_CHECKIN);
        if (!ReminderRules.checkinDue(local.toLocalTime(), at)) {
            return false;
        }
        boolean done = mongo.exists(Query.query(Criteria.where("userId").is(userId).and("localDate").is(date)
            .and("checkin").exists(true)), "daily_stats");
        if (done) {
            return false;
        }
        String text = templates.render("checkin_morning", style(user), Map.of("ten", name(user)), date)
            .orElse(name(user) + ", hôm nay bạn thấy thế nào? Check-in để mình chỉnh buổi tập cho vừa sức nhé.");
        return notifications.send(userId, "checkin_morning", "LevelUp", text,
            userId.toHexString() + "|" + date + "|checkin", Map.of("route", "/checkin"))
            == NotificationGateway.Result.SENT;
    }

    private boolean preWorkout(ObjectId userId, Document user, Document settings, LocalDateTime local, String date) {
        Document plan = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("status").is("active")
            .and("sessions").elemMatch(Criteria.where("scheduledDate").is(date).and("status").is("planned"))),
            Document.class, "training_plans");
        if (plan == null) {
            return false;
        }
        int minutes = settings.get("preWorkoutMinutes") instanceof Number n
            ? n.intValue() : ReminderRules.DEFAULT_PRE_WORKOUT_MINUTES;
        for (Document s : plan.getList("sessions", Document.class, List.of())) {
            if (!date.equals(s.getString("scheduledDate")) || !"planned".equals(s.getString("status"))) {
                continue;
            }
            LocalTime time = ReminderRules.time(s.getString("scheduledTime"), null);
            if (time == null || !ReminderRules.preWorkoutDue(local, LocalDate.parse(date).atTime(time), minutes)) {
                continue;
            }
            ObjectId sessionId = s.getObjectId("_id");
            String title = s.getString("title") == null ? "hôm nay" : s.getString("title");
            Object duration = s.get("durationMin");
            String text = templates.render("pre_workout", style(user), Map.of("ten", name(user), "bai_tap", title,
                    "thoi_luong", (duration instanceof Number d ? d.intValue() : 15) + " phút"), date)
                .orElse(name(user) + ", " + time + " có buổi " + title + ". Chuẩn bị nhé!");
            return notifications.send(userId, "pre_workout", "LevelUp", text,
                userId.toHexString() + "|" + sessionId.toHexString() + "|pre_workout",
                Map.of("route", "/workout/" + sessionId.toHexString())) == NotificationGateway.Result.SENT;
        }
        return false;
    }

    private static String name(Document user) {
        String n = user.getString("displayName");
        return n == null ? "" : n;
    }

    private static String style(Document user) {
        return user.get("profile", new Document()).getString("coachStyle");
    }
}
