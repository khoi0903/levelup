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
import vn.levelup.notifications.NotificationRules;

/**
 * Nhắc check-in buổi sáng (F2), nhắc trước buổi tập và nhắc uống nước (F8, người dùng tự bật),
 * chạy trong /jobs/tick.
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
        if (water(userId, user, settings, local, date)) {
            sent++;
        }
        return sent;
    }

    /** Nhắc uống nước (F8): chỉ khi người dùng tự bật; lượt riêng, không chiếm lượt của nhắc tập. */
    private boolean water(ObjectId userId, Document user, Document settings, LocalDateTime local, String date) {
        if (!Boolean.TRUE.equals(settings.getBoolean("waterReminder"))) {
            return false;
        }
        int target = waterTarget(user, date);
        Document day = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("localDate").is(date)),
            Document.class, "daily_stats");
        int drank = day != null && day.get("waterMl") instanceof Number n ? n.intValue() : 0;
        ReminderRules.WaterSlot slot = ReminderRules.waterDue(local.toLocalTime(), drank, target);
        if (slot == null) {
            return false;
        }
        String text = drank == 0
            ? name(user) + ", hôm nay bạn chưa ghi ly nước nào. Uống một ly nhé!"
            : name(user) + ", bạn mới uống " + drank + "/" + target + " ml nước hôm nay. Uống thêm một ly nhé!";
        return notifications.send(userId, NotificationRules.WATER_TYPE, "LevelUp", text,
            userId.toHexString() + "|" + date + "|water|" + slot.key(), Map.of("route", "/nutrition"))
            == NotificationGateway.Result.SENT;
    }

    /** waterMl của mốc mục tiêu dinh dưỡng mới nhất đã có hiệu lực tới ngày này; 0 nếu chưa có. */
    static int waterTarget(Document user, String date) {
        Document chosen = null;
        for (Document t : user.getList("nutritionTargets", Document.class, List.of())) {
            String from = t.getString("effectiveFrom");
            if (from != null && from.compareTo(date) <= 0 && t.get("waterMl") instanceof Number
                && (chosen == null || from.compareTo(chosen.getString("effectiveFrom")) >= 0)) {
                chosen = t;
            }
        }
        return chosen == null ? 0 : ((Number) chosen.get("waterMl")).intValue();
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
