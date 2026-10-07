package vn.levelup.engagement.service;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.aggregation.Aggregation;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import com.mongodb.client.result.UpdateResult;
import vn.levelup.engagement.dto.ActionRequest;
import vn.levelup.engagement.dto.ActionResponse;
import vn.levelup.engagement.dto.BuddyTodayResponse;
import vn.levelup.engagement.dto.InviteResponse;
import vn.levelup.engagement.dto.PairResponse;
import vn.levelup.engagement.notification.NotificationGateway;
import vn.levelup.engagement.rules.BuddyRules;
import vn.levelup.identity.model.User;
import vn.levelup.shared.util.LocalDates;


/**
 * F5 Buddy. Mọi truy vấn bắt đầu từ userId của người gọi (lấy từ token); dữ liệu của buddy chỉ đọc
 * khi hai người đang ở chung một cặp active, và chỉ trả những gì buddy cho phép chia sẻ.
 * Thông báo đi qua NotificationGateway, gửi sau khi ghi xong.
 */
@Service
public class BuddyService {

    static final Duration INVITE_TTL = Duration.ofDays(7);
    static final int DEFAULT_TARGET = 3;
    private static final int CODE_ATTEMPTS = 5;
    private static final DateTimeFormatter SHARE_DATE = DateTimeFormatter.ofPattern("dd/MM");

    private final MongoTemplate mongo;
    private final NotificationGateway notifications;
    private final Clock clock;
    private final TransactionTemplate tx;
    private final SecureRandom random = new SecureRandom();

    public BuddyService(MongoTemplate mongo, NotificationGateway notifications, Clock clock,
                        PlatformTransactionManager transactionManager) {
        this.mongo = mongo;
        this.notifications = notifications;
        this.clock = clock;
        this.tx = new TransactionTemplate(transactionManager);
    }

    // ---------------------------------------------------------------------
    // POST /buddies/invites
    // ---------------------------------------------------------------------

    /** Mỗi người chỉ có một mã còn hạn: đã có thì trả lại mã đó, chưa có thì tạo mã mới hạn 7 ngày. */
    public InviteResponse invite(User user) {
        ObjectId me = new ObjectId(user.id());
        if (activePair(me) != null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "ALREADY_PAIRED");
        }
        Instant now = clock.instant();
        Document open = mongo.findOne(Query.query(Criteria.where("inviterId").is(me)
                .and("acceptedBy").exists(false).and("expiresAt").gt(Date.from(now)))
            .with(Sort.by(Sort.Direction.DESC, "expiresAt")), Document.class, "buddy_invites");
        if (open != null) {
            return inviteView(user, open.getString("code"), open.getDate("expiresAt").toInstant());
        }

        Instant expiresAt = now.plus(INVITE_TTL).truncatedTo(ChronoUnit.MILLIS);
        for (int i = 0; i < CODE_ATTEMPTS; i++) {
            String code = BuddyRules.newCode(random);
            try {
                mongo.insert(new Document("inviterId", me).append("code", code)
                    .append("expiresAt", Date.from(expiresAt)).append("createdAt", Date.from(now)), "buddy_invites");
                return inviteView(user, code, expiresAt);
            } catch (DuplicateKeyException e) {
                // Trùng mã của người khác (rất hiếm): thử mã khác
            }
        }
        throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "INVITE_CODE_UNAVAILABLE");
    }

    private static InviteResponse inviteView(User user, String code, Instant expiresAt) {
        String until = expiresAt.atZone(LocalDates.zone(user.timezone())).format(SHARE_DATE);
        String shareText = ("%s rủ bạn tập cùng trên LevelUp! Mình nhắc nhau tập mỗi ngày nhé. "
            + "Mở app LevelUp, vào mục Buddy, chọn \"Nhập mã mời\" và gõ %s (dùng được đến hết %s).")
            .formatted(user.displayName(), code, until);
        return new InviteResponse(code, expiresAt, shareText);
    }

    // ---------------------------------------------------------------------
    // POST /buddies/join
    // ---------------------------------------------------------------------

    public PairResponse join(User user, String rawCode) {
        ObjectId me = new ObjectId(user.id());
        Instant now = clock.instant();
        String code = BuddyRules.normalizeCode(rawCode);
        Document invite = code.length() == BuddyRules.CODE_LENGTH
            ? mongo.findOne(Query.query(Criteria.where("code").is(code)), Document.class, "buddy_invites")
            : null;
        if (invite == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "INVITE_NOT_FOUND");
        }
        ObjectId inviterId = invite.getObjectId("inviterId");
        if (me.equals(inviterId)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "OWN_INVITE");
        }
        if (invite.get("acceptedBy") != null) {
            throw new ResponseStatusException(HttpStatus.GONE, "INVITE_USED");
        }
        if (!invite.getDate("expiresAt").toInstant().isAfter(now)) {
            throw new ResponseStatusException(HttpStatus.GONE, "INVITE_EXPIRED");
        }
        Document inviter = mongo.findById(inviterId, Document.class, "users");
        if (inviter == null || inviter.get("deletedAt") != null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "INVITE_NOT_FOUND");
        }
        if (activePair(me) != null || activePair(inviterId) != null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "ALREADY_PAIRED");
        }

        ObjectId pairId = new ObjectId();
        tx.executeWithoutResult(status -> {
            UpdateResult used = mongo.updateFirst(Query.query(Criteria.where("_id").is(invite.getObjectId("_id"))
                    .and("acceptedBy").exists(false)),
                new Update().set("acceptedBy", me).set("acceptedAt", Date.from(now)), "buddy_invites");
            if (used.getModifiedCount() == 0) {
                throw new ResponseStatusException(HttpStatus.GONE, "INVITE_USED");
            }
            try {
                // Index unique pairKey và members (khi active) chặn hai request ghép song song
                mongo.insert(new Document("_id", pairId)
                    .append("members", List.of(inviterId, me))
                    .append("pairKey", BuddyRules.pairKey(inviterId, me))
                    .append("status", "active")
                    .append("sharedStreakWeeks", 0)
                    .append("createdAt", Date.from(now)), "buddy_pairs");
            } catch (DuplicateKeyException e) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "ALREADY_PAIRED");
            }
        });

        notifications.send(inviterId, "buddy_paired", "Đã có bạn tập cùng",
            "%s đã nhận lời mời. Từ hôm nay hai bạn thấy nhau tập chưa và nhắc nhau được rồi!"
                .formatted(user.displayName()),
            "paired:" + pairId.toHexString(), Map.of("route", "/buddy", "pairId", pairId.toHexString()));
        return new PairResponse(pairId.toHexString(), inviter.getString("displayName"), now);
    }

    // ---------------------------------------------------------------------
    // GET /buddies/today
    // ---------------------------------------------------------------------

    public BuddyTodayResponse today(User user) {
        ObjectId me = new ObjectId(user.id());
        Document pair = activePair(me);
        if (pair == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "NO_BUDDY");
        }
        ObjectId buddyId = other(pair, me);
        Document buddy = mongo.findById(buddyId, Document.class, "users");
        if (buddy == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "NO_BUDDY");
        }

        LocalDate buddyToday = LocalDates.today(buddy.getString("timezone"), clock);
        String weekStart = LocalDates.weekStart(buddyToday).toString();
        Document plan = activePlan(buddyId, weekStart);
        BuddyRules.TodayStatus status = buddyStatus(buddyId, buddyToday, plan);
        Document streak = buddy.get("streak", Document.class);

        LocalDate myToday = LocalDates.today(user.timezone(), clock);
        Set<String> mine = mongo.find(Query.query(Criteria.where("fromUser").is(me).and("toUser").is(buddyId)
                .and("localDate").is(myToday.toString())), Document.class, "buddy_actions")
            .stream().map(d -> d.getString("action")).collect(Collectors.toSet());

        BuddyRules.Sharing sharing = BuddyRules.Sharing.from(buddy.get("sharing", Document.class));
        BuddyTodayResponse.Shared shared = BuddyRules.filter(sharing, loadShared(buddyId, sharing, buddyToday));

        return new BuddyTodayResponse(
            pair.getObjectId("_id").toHexString(),
            pair.getDate("createdAt") == null ? null : pair.getDate("createdAt").toInstant(),
            intOrNull(pair, "sharedStreakWeeks"),
            new BuddyTodayResponse.Buddy(buddy.getString("displayName"), buddyToday.toString(), status.status(),
                status.scheduledTime(), status.title(), week(buddyId, weekStart, plan),
                streak == null || intOrNull(streak, "currentWeeks") == null ? 0 : intOrNull(streak, "currentWeeks")),
            new BuddyTodayResponse.MyActions(mine.contains("nudge"), mine.contains("cheer")),
            shared);
    }

    private BuddyRules.TodayStatus buddyStatus(ObjectId buddyId, LocalDate day, Document plan) {
        boolean trained = mongo.exists(Query.query(Criteria.where("userId").is(buddyId)
            .and("localDate").is(day.toString()).and("countsForStreak").is(true)), "workout_logs");
        List<BuddyRules.PlannedSession> sessions = plan == null ? List.of()
            : plan.getList("sessions", Document.class, List.of()).stream()
                .filter(s -> day.toString().equals(s.getString("scheduledDate")))
                .map(s -> new BuddyRules.PlannedSession(s.getString("status"), s.getString("scheduledTime"),
                    s.getString("title")))
                .toList();
        return BuddyRules.todayStatus(trained, plan != null, sessions);
    }

    private Document activePlan(ObjectId userId, String weekStart) {
        return mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(weekStart)
            .and("status").is("active")), Document.class, "training_plans");
    }

    private BuddyTodayResponse.Week week(ObjectId userId, String weekStart, Document plan) {
        Document week = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(weekStart)),
            Document.class, "weekly_streaks");
        if (week != null) {
            return new BuddyTodayResponse.Week(weekStart, intOrNull(week, "completedSessions"),
                intOrNull(week, "targetSessions"));
        }
        Integer target = plan == null ? null : intOrNull(plan, "targetSessions");
        return new BuddyTodayResponse.Week(weekStart, 0, target == null ? DEFAULT_TARGET : target);
    }

    /** Chỉ đọc những mục buddy đã bật; mặc định không đọc gì. */
    private BuddyTodayResponse.Shared loadShared(ObjectId buddyId, BuddyRules.Sharing sharing, LocalDate day) {
        if (sharing.equals(BuddyRules.Sharing.NONE)) {
            return null;
        }
        Double weightKg = null;
        if (sharing.weight()) {
            Document m = latestMeasurement(buddyId, Criteria.where("weightKg").exists(true));
            weightKg = m == null ? null : ((Number) m.get("weightKg")).doubleValue();
        }
        BuddyTodayResponse.Measurements measurements = null;
        if (sharing.measurements()) {
            Document m = latestMeasurement(buddyId, new Criteria().orOperator(Criteria.where("waistCm").exists(true),
                Criteria.where("hipCm").exists(true), Criteria.where("chestCm").exists(true),
                Criteria.where("armCm").exists(true)));
            if (m != null) {
                measurements = new BuddyTodayResponse.Measurements(m.getString("measuredOn"), doubleOrNull(m, "waistCm"),
                    doubleOrNull(m, "hipCm"), doubleOrNull(m, "chestCm"), doubleOrNull(m, "armCm"));
            }
        }
        Integer mealsKcal = null;
        if (sharing.meals()) {
            Document sum = mongo.aggregate(Aggregation.newAggregation(
                    Aggregation.match(Criteria.where("userId").is(buddyId).and("localDate").is(day.toString())),
                    Aggregation.group().sum("kcal").as("kcal")), "meal_logs", Document.class)
                .getUniqueMappedResult();
            mealsKcal = sum == null ? 0 : ((Number) sum.get("kcal")).intValue();
        }
        return new BuddyTodayResponse.Shared(weightKg, measurements, mealsKcal);
    }

    private Document latestMeasurement(ObjectId userId, Criteria has) {
        return mongo.findOne(Query.query(new Criteria().andOperator(Criteria.where("userId").is(userId), has))
            .with(Sort.by(Sort.Direction.DESC, "measuredOn")), Document.class, "body_measurements");
    }

    // ---------------------------------------------------------------------
    // POST /buddies/{pairId}/actions
    // ---------------------------------------------------------------------

    public ActionResponse act(User user, String pairIdHex, ActionRequest request) {
        ObjectId me = new ObjectId(user.id());
        if (!ObjectId.isValid(pairIdHex)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "PAIR_NOT_FOUND");
        }
        ObjectId pairId = new ObjectId(pairIdHex);
        Document pair = mongo.findOne(Query.query(Criteria.where("_id").is(pairId).and("members").is(me)
            .and("status").is("active")), Document.class, "buddy_pairs");
        if (pair == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "PAIR_NOT_FOUND");
        }
        ObjectId buddyId = other(pair, me);
        boolean nudge = "nudge".equals(request.type());

        if (nudge) {
            Document buddy = mongo.findById(buddyId, Document.class, "users");
            LocalDate buddyToday = LocalDates.today(buddy == null ? null : buddy.getString("timezone"), clock);
            Document plan = activePlan(buddyId, LocalDates.weekStart(buddyToday).toString());
            if ("done".equals(buddyStatus(buddyId, buddyToday, plan).status())) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "BUDDY_DONE");
            }
        }

        String localDate = LocalDates.today(user.timezone(), clock).toString();
        String message = request.message() == null || request.message().isBlank() ? null : request.message().strip();
        Document action = new Document("pairId", pairId).append("fromUser", me).append("toUser", buddyId)
            .append("action", request.type()).append("localDate", localDate)
            .append("createdAt", Date.from(clock.instant()));
        if (message != null) {
            action.append("message", message);
        }
        try {
            mongo.insert(action, "buddy_actions");
        } catch (DuplicateKeyException e) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, nudge ? "ALREADY_NUDGED" : "ALREADY_CHEERED");
        }

        String title = nudge ? "%s nhắc bạn tập hôm nay".formatted(user.displayName())
            : "%s cổ vũ bạn".formatted(user.displayName());
        String body = message != null ? message
            : nudge ? "Hôm nay tập chưa? Một buổi ngắn 5 phút cũng giữ được streak đó!"
            : "Tập tốt lắm, giữ phong độ nhé!";
        notifications.send(buddyId, nudge ? "buddy_nudge" : "buddy_cheer", title, body,
            "%s:%s:%s:%s".formatted(request.type(), pairId.toHexString(), me.toHexString(), localDate),
            Map.of("route", "/buddy", "pairId", pairId.toHexString()));
        return new ActionResponse(request.type(), localDate);
    }

    // ---------------------------------------------------------------------
    // DELETE /buddies/pair
    // ---------------------------------------------------------------------

    /** Rời cặp. Không gửi thông báo cho người còn lại; app của họ thấy NO_BUDDY ở lần mở sau. */
    public void leave(User user) {
        ObjectId me = new ObjectId(user.id());
        UpdateResult ended = mongo.updateFirst(Query.query(Criteria.where("members").is(me).and("status").is("active")),
            new Update().set("status", "ended").set("endedAt", Date.from(clock.instant())), "buddy_pairs");
        if (ended.getModifiedCount() == 0) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "NO_BUDDY");
        }
    }

    // ---------------------------------------------------------------------

    private Document activePair(ObjectId userId) {
        return mongo.findOne(Query.query(Criteria.where("members").is(userId).and("status").is("active")),
            Document.class, "buddy_pairs");
    }

    private static ObjectId other(Document pair, ObjectId me) {
        return pair.getList("members", ObjectId.class).stream().filter(id -> !id.equals(me)).findFirst()
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "NO_BUDDY"));
    }

    private static Integer intOrNull(Document d, String key) {
        return d.get(key) instanceof Number n ? n.intValue() : null;
    }

    private static Double doubleOrNull(Document d, String key) {
        return d.get(key) instanceof Number n ? n.doubleValue() : null;
    }
}
