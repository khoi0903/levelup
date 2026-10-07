package vn.levelup.engagement.notification;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.Date;
import java.util.List;
import java.util.Map;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import vn.levelup.engagement.rules.NotificationRules;
import vn.levelup.shared.util.LocalDates;


/**
 * Cổng gửi thông báo thật, theo flowchart "Cổng gửi thông báo" trong docs/04-backend-flow.html:
 * pushEnabled và thiết bị → giờ yên lặng → bộ đếm mỗi ngày (tăng trong cùng một lệnh) →
 * insert notifications với dedupeKey → gửi push → xóa token hết hạn.
 *
 * Chạy ngoài transaction của nơi gọi: lỗi trùng khóa (E11000) là chuyện bình thường ở đây
 * và không được làm hủy transaction đang ghi dữ liệu khác.
 */
@Service
@Transactional(propagation = Propagation.NOT_SUPPORTED)
public class MongoNotificationGateway implements NotificationGateway {

    private static final Logger log = LoggerFactory.getLogger(MongoNotificationGateway.class);

    /** Khớp notifications.type trong mongo/init.js: không giới hạn danh sách, để module mới gửi được type mới. */
    private static final java.util.regex.Pattern TYPE = java.util.regex.Pattern.compile("[a-z0-9_]{1,40}");

    /** Thông báo hẹn quá chừng này mà chưa gửi được thì bỏ push. */
    static final java.time.Duration SCHEDULE_TTL = java.time.Duration.ofHours(12);

    private final MongoTemplate mongo;
    private final PushSender push;
    private final Clock clock;

    public MongoNotificationGateway(MongoTemplate mongo, PushSender push, Clock clock) {
        this.mongo = mongo;
        this.push = push;
        this.clock = clock;
    }

    @Override
    public Result send(ObjectId userId, String type, String title, String body, String dedupeKey,
                       Map<String, String> data) {
        if (type == null || !TYPE.matcher(type).matches()) {
            throw new IllegalArgumentException("type thông báo phải dạng a-z0-9_ (khớp validator notifications)");
        }
        Instant now = clock.instant();
        Document user = mongo.findById(userId, Document.class, "users");
        Document settings = user == null ? new Document() : user.get("notificationSettings", new Document());
        List<Document> devices = user == null ? List.of() : user.getList("devices", Document.class, List.of());
        ZoneId zone = LocalDates.zone(user == null ? null : user.getString("timezone"));
        String localDate = LocalDates.today(zone.getId(), clock).toString();

        LocalTime quietStart = NotificationRules.time(settings.getString("quietStart"),
            NotificationRules.DEFAULT_QUIET_START);
        LocalTime quietEnd = NotificationRules.time(settings.getString("quietEnd"), NotificationRules.DEFAULT_QUIET_END);
        boolean quiet = NotificationRules.isQuiet(now.atZone(zone).toLocalTime(), quietStart, quietEnd);
        boolean pushEnabled = !Boolean.FALSE.equals(settings.getBoolean("pushEnabled"));

        Document notification = new Document("userId", userId)
            .append("type", type)
            .append("localDate", localDate)
            .append("title", title)
            .append("body", body)
            .append("createdAt", Date.from(now));
        if (dedupeKey != null) {
            notification.append("dedupeKey", dedupeKey);
        }
        if (data != null && !data.isEmpty()) {
            notification.append("data", new Document(data));
        }

        switch (NotificationRules.gate(pushEnabled, devices.size(), quiet)) {
            case STORE_ONLY -> {
                notification.append("channel", "in_app").append("scheduledFor", Date.from(now));
                return insert(notification) ? Result.STORED_ONLY : Result.DUPLICATE;
            }
            case QUIET_HOURS -> {
                // /jobs/tick gửi lại lúc quietEnd (dispatchDue)
                notification.append("channel", "push")
                    .append("scheduledFor", Date.from(NotificationRules.nextQuietEnd(now, zone, quietEnd)));
                return insert(notification) ? Result.QUIET_HOURS : Result.DUPLICATE;
            }
            case TRY_SEND -> {
                // fall through
            }
        }

        if (dedupeKey != null && mongo.exists(Query.query(Criteria.where("dedupeKey").is(dedupeKey)),
                "notifications")) {
            return Result.DUPLICATE;
        }
        String counter = NotificationRules.counterField(type);
        int limit = NotificationRules.limitFor(type, settings.get("maxPerDay"));
        if (limit == 0 || !takeDailySlot(userId, localDate, counter, limit)) {
            log.info("[notify] hết lượt trong ngày user={} type={} key={}", userId, type, dedupeKey);
            return Result.DAILY_LIMIT;
        }

        notification.append("channel", "push").append("scheduledFor", Date.from(now));
        if (!insert(notification)) {
            releaseDailySlot(userId, localDate, counter);
            return Result.DUPLICATE;
        }

        return deliver(userId, devices, notification.getObjectId("_id"), title, body, data, localDate, counter)
            ? Result.SENT : Result.STORED_ONLY;
    }

    /**
     * Gửi các thông báo đã hẹn (giờ yên lặng) khi tới scheduledFor. Quá {@link #SCHEDULE_TTL} thì bỏ push,
     * chỉ giữ trong app. Hết lượt trong ngày thì để lần tick sau. Job /jobs/tick gọi cho từng người dùng.
     *
     * @return số thông báo đã gửi
     */
    public int dispatchDue(ObjectId userId) {
        Instant now = clock.instant();
        List<Document> due = mongo.find(Query.query(Criteria.where("userId").is(userId).and("channel").is("push")
            .and("sentAt").exists(false).and("scheduledFor").lte(Date.from(now))), Document.class, "notifications");
        if (due.isEmpty()) {
            return 0;
        }
        Document user = mongo.findById(userId, Document.class, "users");
        if (user == null) {
            return 0;
        }
        Document settings = user.get("notificationSettings", new Document());
        List<Document> devices = user.getList("devices", Document.class, List.of());
        ZoneId zone = LocalDates.zone(user.getString("timezone"));
        String localDate = LocalDates.today(zone.getId(), clock).toString();
        boolean quiet = NotificationRules.isQuiet(now.atZone(zone).toLocalTime(),
            NotificationRules.time(settings.getString("quietStart"), NotificationRules.DEFAULT_QUIET_START),
            NotificationRules.time(settings.getString("quietEnd"), NotificationRules.DEFAULT_QUIET_END));
        boolean pushEnabled = !Boolean.FALSE.equals(settings.getBoolean("pushEnabled"));
        int sent = 0;
        for (Document n : due) {
            ObjectId id = n.getObjectId("_id");
            boolean expired = n.getDate("scheduledFor").toInstant().plus(SCHEDULE_TTL).isBefore(now);
            if (expired || !pushEnabled || devices.isEmpty()) {
                mongo.updateFirst(Query.query(Criteria.where("_id").is(id)), Update.update("channel", "in_app"),
                    "notifications");
                continue;
            }
            String counter = NotificationRules.counterField(n.getString("type"));
            int limit = NotificationRules.limitFor(n.getString("type"), settings.get("maxPerDay"));
            if (quiet || limit == 0 || !takeDailySlot(userId, localDate, counter, limit)) {
                continue;
            }
            Map<String, String> data = new java.util.HashMap<>();
            n.get("data", new Document()).forEach((k, v) -> data.put(k, String.valueOf(v)));
            if (deliver(userId, devices, id, n.getString("title"), n.getString("body"), data, localDate, counter)) {
                sent++;
            }
        }
        return sent;
    }

    /** Gửi tới mọi thiết bị, xóa token hết hạn. Không thiết bị nào nhận thì trả lượt và chỉ giữ trong app. */
    private boolean deliver(ObjectId userId, List<Document> devices, ObjectId notificationId, String title,
                            String body, Map<String, String> data, String localDate, String counter) {
        boolean delivered = false;
        for (Document device : devices) {
            String token = device.getString("token");
            if (token == null) {
                continue;
            }
            PushSender.Outcome outcome = push.send(token, device.getString("platform"), title, body,
                data == null ? Map.of() : data);
            if (outcome == PushSender.Outcome.TOKEN_EXPIRED) {
                mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)),
                    new Update().pull("devices", new Document("token", token)), "users");
            }
            delivered |= outcome == PushSender.Outcome.SENT;
        }
        Query byId = Query.query(Criteria.where("_id").is(notificationId));
        if (!delivered) {
            releaseDailySlot(userId, localDate, counter);
            mongo.updateFirst(byId, Update.update("channel", "in_app"), "notifications");
            return false;
        }
        mongo.updateFirst(byId, Update.update("sentAt", Date.from(clock.instant())), "notifications");
        return true;
    }

    /** false khi trùng dedupeKey. */
    private boolean insert(Document notification) {
        try {
            mongo.insert(notification, "notifications");
            return true;
        } catch (DuplicateKeyException e) {
            return false;
        }
    }

    /**
     * Tăng bộ đếm trong daily_stats (notificationsSent, hoặc waterRemindersSent cho nhắc uống nước)
     * nếu còn nhỏ hơn giới hạn, trong một lệnh.
     * Hết lượt thì điều kiện không khớp, upsert tạo document thứ hai cho cùng (userId, localDate)
     * và bị unique index chặn: đó là tín hiệu hết lượt.
     */
    private boolean takeDailySlot(ObjectId userId, String localDate, String counter, int limit) {
        Query query = Query.query(Criteria.where("userId").is(userId).and("localDate").is(localDate)
            .orOperator(Criteria.where(counter).lt(limit), Criteria.where(counter).exists(false)));
        try {
            mongo.upsert(query, new Update().inc(counter, 1), "daily_stats");
            return true;
        } catch (DuplicateKeyException e) {
            return false;
        }
    }

    private void releaseDailySlot(ObjectId userId, String localDate, String counter) {
        mongo.updateFirst(Query.query(Criteria.where("userId").is(userId).and("localDate").is(localDate)
            .and(counter).gt(0)), new Update().inc(counter, -1), "daily_stats");
    }
}
