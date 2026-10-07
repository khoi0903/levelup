package vn.levelup.engagement.service;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Service;
import vn.levelup.engagement.notification.MongoNotificationGateway;
import vn.levelup.engagement.rules.JobRules;
import vn.levelup.shared.util.LocalDates;


/**
 * /jobs/tick: duyệt người dùng theo trang, mỗi người xét theo giờ địa phương của họ:
 * chốt ngày (từ 00:05), chốt tuần (Chủ nhật từ 19:00, bù tuần trước nếu lỡ), gửi thông báo đã hẹn.
 * Lỗi của một người dùng chỉ ghi log, không dừng cả lượt.
 */
@Service
public class JobService {

    private static final Logger log = LoggerFactory.getLogger(JobService.class);
    static final int PAGE_SIZE = 200;

    private final MongoTemplate mongo;
    private final DailyCloseService dailyClose;
    private final WeekCloseService weekClose;
    private final MongoNotificationGateway notifications;
    private final ReminderService reminders;
    private final Clock clock;

    public JobService(MongoTemplate mongo, DailyCloseService dailyClose, WeekCloseService weekClose,
                      MongoNotificationGateway notifications, ReminderService reminders, Clock clock) {
        this.mongo = mongo;
        this.dailyClose = dailyClose;
        this.weekClose = weekClose;
        this.notifications = notifications;
        this.reminders = reminders;
        this.clock = clock;
    }

    public record TickResult(int users, int sessionsSkipped, int weeksClosed, int notificationsSent, int errors) {}

    public TickResult tick() {
        int users = 0;
        int skipped = 0;
        int weeks = 0;
        int sent = 0;
        int errors = 0;
        ObjectId after = null;
        while (true) {
            Criteria criteria = Criteria.where("deletedAt").exists(false);
            if (after != null) {
                criteria = criteria.and("_id").gt(after);
            }
            Query page = Query.query(criteria).with(Sort.by("_id")).limit(PAGE_SIZE);
            page.fields().include("_id", "timezone");
            List<Document> batch = mongo.find(page, Document.class, "users");
            for (Document u : batch) {
                ObjectId userId = u.getObjectId("_id");
                after = userId;
                users++;
                try {
                    LocalDateTime local = LocalDateTime.now(clock.withZone(LocalDates.zone(u.getString("timezone"))));
                    skipped += dailyClose.closeDay(userId, JobRules.dayToClose(local)).skipped();
                    LocalDate thisWeek = LocalDates.weekStart(local.toLocalDate());
                    if (weekClose.closeWeek(userId, thisWeek.minusWeeks(1)).closed()) {
                        weeks++;
                    }
                    if (JobRules.weekCloseDue(local) && weekClose.closeWeek(userId, thisWeek).closed()) {
                        weeks++;
                    }
                    sent += notifications.dispatchDue(userId);
                    sent += reminders.remind(userId, local);
                } catch (RuntimeException e) {
                    errors++;
                    log.error("[tick] lỗi user={}: {}", userId, e.getMessage(), e);
                }
            }
            if (batch.size() < PAGE_SIZE) {
                break;
            }
        }
        TickResult result = new TickResult(users, skipped, weeks, sent, errors);
        log.info("[tick] {}", result);
        return result;
    }
}
