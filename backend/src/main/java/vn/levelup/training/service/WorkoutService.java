package vn.levelup.training.service;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.stream.StreamSupport;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.FindAndModifyOptions;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.identity.model.User;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.WorkoutRequest;
import vn.levelup.training.dto.WorkoutResponse;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.repository.ExerciseRepository;
import vn.levelup.training.rules.RpeRules;
import vn.levelup.training.rules.WorkoutRules;


@Service
public class WorkoutService {

    static final int MAX_DURATION_SEC = 6 * 3600;
    static final int DEFAULT_TARGET = 3;
    static final String COMEBACK = "comeback_days_7";
    private static final Duration CLOCK_SKEW = Duration.ofMinutes(5);
    /**
     * startedAt do app gửi (giờ điện thoại, sửa được). Chỉ cộng chỉ tiêu tuần cho buổi bắt đầu trong khoảng này
     * tính theo giờ máy chủ: chỉnh lùi ngày trên máy không cộng được vào ngày/tuần cũ; nháp offline gửi trễ quá
     * thì vẫn lưu lịch sử nhưng không tính.
     */
    static final Duration STREAK_WINDOW = Duration.ofHours(24);

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final Clock clock;
    private final RpeAdjuster rpeAdjuster;

    public WorkoutService(MongoTemplate mongo, ExerciseRepository exercises, Clock clock, RpeAdjuster rpeAdjuster) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.clock = clock;
        this.rpeAdjuster = rpeAdjuster;
    }

    /**
     * Lưu buổi tập và mọi thứ đi kèm trong một transaction. App gửi lại cùng clientId
     * (mất mạng, bấm hai lần) thì trả kết quả của lần đầu, không lưu trùng.
     * Chỉnh buổi kế tiếp theo RPE (RpeAdjuster). Chưa làm ở đây: báo buddy.
     */
    @Transactional
    public WorkoutResponse save(User user, WorkoutRequest r) {
        ObjectId userId = new ObjectId(user.id());
        Instant now = clock.instant();
        long durationSec = Duration.between(r.startedAt(), r.endedAt()).toSeconds();
        if (durationSec < 0 || durationSec > MAX_DURATION_SEC || r.startedAt().isAfter(now.plus(CLOCK_SKEW))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_TIME");
        }

        Document existing = mongo.findOne(byClientId(userId, r.clientId()), Document.class, "workout_logs");
        if (existing != null) {
            return replay(userId, existing);
        }

        Set<String> exerciseIds = r.sets().stream().map(WorkoutRequest.SetLog::exerciseId)
            .collect(Collectors.toCollection(LinkedHashSet::new));
        List<Exercise> used = StreamSupport.stream(exercises.findAllById(exerciseIds).spliterator(), false).toList();
        Map<String, String> names = used.stream().collect(Collectors.toMap(Exercise::id, Exercise::nameVi));
        Map<String, Double> mets = new HashMap<>();
        used.forEach(e -> mets.put(e.id(), e.met()));
        if (names.size() != exerciseIds.size()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "UNKNOWN_EXERCISE");
        }

        LocalDate localDate = r.startedAt().atZone(LocalDates.zone(user.timezone())).toLocalDate();
        String weekStart = LocalDates.weekStart(localDate).toString();
        boolean fresh = !r.startedAt().isBefore(now.minus(STREAK_WINDOW));
        boolean counts = fresh && WorkoutRules.countsForStreak(durationSec);
        // Ngày hôm nay theo giờ máy chủ (múi giờ người dùng), không theo giờ điện thoại
        LocalDate serverToday = LocalDates.today(user.timezone(), clock);
        int kcalBurned = WorkoutRules.kcalBurned(r.sets(), mets, durationSec, latestWeightKg(userId, user));
        ObjectId logId = new ObjectId();

        // Kỷ lục: so với personal_records trước khi ghi, để đánh dấu isPr ngay trong log
        List<Document> newRecords = new ArrayList<>();
        Set<String> prSets = new HashSet<>();
        List<WorkoutRules.Best> bests = WorkoutRules.bests(r.sets());
        Map<WorkoutRules.Best, Double> previous = new HashMap<>();
        for (WorkoutRules.Best b : bests) {
            Document pr = mongo.findOne(recordQuery(userId, b), Document.class, "personal_records");
            Double prev = pr == null ? null : ((Number) pr.get("value")).doubleValue();
            previous.put(b, prev);
            if (WorkoutRules.isNewRecord(prev, b.value())) {
                prSets.add(b.exerciseId() + "#" + b.setIndex());
                newRecords.add(new Document("exerciseId", b.exerciseId()).append("metric", b.metric())
                    .append("value", b.value()).append("previous", prev));
            }
        }

        // 1. workout_logs
        Document log = new Document("_id", logId)
            .append("userId", userId)
            .append("clientId", r.clientId())
            .append("startedAt", Date.from(r.startedAt()))
            .append("endedAt", Date.from(r.endedAt()))
            .append("localDate", localDate.toString())
            .append("weekStart", weekStart)
            .append("durationSec", durationSec)
            .append("variant", r.variant())
            .append("countsForStreak", counts)
            .append("kcalBurned", kcalBurned)
            .append("sets", r.sets().stream().map(s -> setDocument(s, now, prSets)).toList())
            .append("newRecords", newRecords)
            .append("createdAt", Date.from(now));
        putIfPresent(log, "rpe", r.rpe());
        putIfPresent(log, "painAreas", r.painAreas());
        putIfPresent(log, "note", r.note());

        // 2. Buổi trong kế hoạch: planned -> completed
        TrainingPlan plan = null;
        if (r.plannedSessionId() != null && localDate.equals(serverToday)) {
            ObjectId sessionId = new ObjectId(r.plannedSessionId());
            // Lịch dùng để nhắc: chỉ tập đúng ngày của buổi (hôm nay theo giờ máy chủ) mới tính buổi đó.
            // Tập ngày khác (sớm hơn lịch hay sau khi lỡ) là "tập thêm", tính riêng: lưu log nhưng không đánh
            // dấu lịch, không có tập bù.
            Query session = Query.query(Criteria.where("userId").is(userId).and("status").is("active")
                .and("sessions").elemMatch(Criteria.where("_id").is(sessionId).and("status").is("planned")
                    .and("scheduledDate").is(localDate.toString())));
            plan = mongo.findOne(session, TrainingPlan.class);
            if (plan != null) {
                log.append("plannedSessionId", sessionId);
                log.append("planId", new ObjectId(plan.id()));
                mongo.updateFirst(session, Update.update("sessions.$.status", "completed"), TrainingPlan.class);
            }
        }

        try {
            mongo.insert(log, "workout_logs");
        } catch (DuplicateKeyException e) {
            // Hai request cùng clientId chạy song song: transaction này hủy, app gửi lại sẽ nhận bản đã lưu
            throw new ResponseStatusException(HttpStatus.CONFLICT, "WORKOUT_IN_PROGRESS");
        }

        // 3. personal_records: lưu mốc lần đầu và mốc vượt
        for (WorkoutRules.Best b : bests) {
            Double prev = previous.get(b);
            if (prev == null || b.value() > prev) {
                mongo.upsert(recordQuery(userId, b), new Update().set("value", b.value())
                    .set("workoutLogId", logId).set("achievedAt", Date.from(r.endedAt())), "personal_records");
            }
        }

        // 4. weekly_streaks
        WorkoutResponse.Week week = counts ? addToWeek(userId, weekStart) : readWeek(userId, weekStart);

        // 5. users: quay lại trạng thái active, huy hiệu số buổi, huy hiệu quay lại sau 7 ngày
        Document previousLog = mongo.findOne(Query.query(Criteria.where("userId").is(userId)
            .and("_id").ne(logId).and("endedAt").lte(Date.from(r.startedAt())))
            .with(Sort.by(Sort.Direction.DESC, "endedAt")), Document.class, "workout_logs");
        Update userUpdate = new Update()
            .set("reengagement.stage", "active")
            .set("reengagement.lastWorkoutAt", Date.from(r.endedAt()))
            .set("reengagement.consecutiveMissed", 0)
            .set("reengagement.messagesInStage", 0)
            .set("lastActiveAt", Date.from(now));
        List<String> earned = new ArrayList<>();
        Set<String> owned = ownedAchievements(userId);
        if (counts) {
            long counted = mongo.count(Query.query(Criteria.where("userId").is(userId)
                .and("countsForStreak").is(true)), "workout_logs");
            WorkoutRules.sessionMilestone(counted, owned).ifPresent(earned::add);
        }
        if (previousLog != null && !owned.contains(COMEBACK)
                && RpeRules.isComeback(previousLog.getDate("endedAt").toInstant(), r.startedAt())) {
            earned.add(COMEBACK);
        }
        if (!earned.isEmpty()) {
            userUpdate.push("achievements").each(earned.stream().map(code -> new Document("code", code)
                .append("earnedAt", Date.from(now)).append("context", new Document("workoutLogId", logId)))
                .toArray());
        }
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)), userUpdate, "users");

        // 6. Buổi kế tiếp theo RPE và vùng đau (không chạy khi app gửi lại, vì đã return ở trên)
        rpeAdjuster.adjustNext(userId, localDate,
            r.plannedSessionId() == null ? null : new ObjectId(r.plannedSessionId()), r.rpe(), r.painAreas());

        return new WorkoutResponse(logId.toHexString(), localDate.toString(), durationSec, counts, false, week,
            recordViews(newRecords, names), achievementViews(earned), kcalBurned);
    }

    /** Lần cân gần nhất; chưa cân thì cân nặng lúc onboarding; không có thì mức mặc định. */
    private double latestWeightKg(ObjectId userId, User user) {
        Document m = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("weightKg").exists(true))
            .with(Sort.by(Sort.Direction.DESC, "measuredOn")), Document.class, "body_measurements");
        if (m != null && m.get("weightKg") instanceof Number n && n.doubleValue() > 0) {
            return n.doubleValue();
        }
        if (user.profile() != null && user.profile().startWeightKg() != null) {
            return user.profile().startWeightKg();
        }
        return WorkoutRules.DEFAULT_WEIGHT_KG;
    }

    /** Kết quả của lần lưu trước, dựng lại từ dữ liệu đã ghi. */
    private WorkoutResponse replay(ObjectId userId, Document log) {
        ObjectId logId = log.getObjectId("_id");
        String weekStart = log.getString("weekStart");
        List<Document> records = log.getList("newRecords", Document.class, List.of());
        Set<String> ids = records.stream().map(d -> d.getString("exerciseId")).collect(Collectors.toSet());
        Map<String, String> names = StreamSupport.stream(exercises.findAllById(ids).spliterator(), false)
            .collect(Collectors.toMap(Exercise::id, Exercise::nameVi));
        Document user = mongo.findById(userId, Document.class, "users");
        List<String> earned = user == null ? List.of() : user.getList("achievements", Document.class, List.of())
            .stream()
            .filter(a -> a.get("context") instanceof Document c && logId.equals(c.get("workoutLogId")))
            .map(a -> a.getString("code"))
            .toList();
        return new WorkoutResponse(logId.toHexString(), log.getString("localDate"),
            ((Number) log.get("durationSec")).longValue(), Boolean.TRUE.equals(log.getBoolean("countsForStreak")),
            true, readWeek(userId, weekStart), recordViews(records, names), achievementViews(earned),
            log.get("kcalBurned") instanceof Number k ? k.intValue() : 0);
    }

    private WorkoutResponse.Week addToWeek(ObjectId userId, String weekStart) {
        Document week = mongo.findAndModify(weekQuery(userId, weekStart),
            new Update().inc("completedSessions", 1)
                .setOnInsert("targetSessions", planTarget(userId, weekStart))
                .setOnInsert("status", "in_progress"),
            FindAndModifyOptions.options().upsert(true).returnNew(true), Document.class, "weekly_streaks");
        WorkoutResponse.Week view = weekView(weekStart, week);
        String status = WorkoutRules.weekStatus(view.status(), view.completedSessions(), view.targetSessions());
        if (!status.equals(view.status())) {
            mongo.updateFirst(weekQuery(userId, weekStart), Update.update("status", status), "weekly_streaks");
            view = new WorkoutResponse.Week(weekStart, view.targetSessions(), view.completedSessions(), status);
        }
        return view;
    }

    private WorkoutResponse.Week readWeek(ObjectId userId, String weekStart) {
        Document week = mongo.findOne(weekQuery(userId, weekStart), Document.class, "weekly_streaks");
        if (week == null) {
            return new WorkoutResponse.Week(weekStart, planTarget(userId, weekStart), 0, "in_progress");
        }
        return weekView(weekStart, week);
    }

    private static WorkoutResponse.Week weekView(String weekStart, Document week) {
        return new WorkoutResponse.Week(weekStart, ((Number) week.get("targetSessions")).intValue(),
            ((Number) week.get("completedSessions")).intValue(), week.getString("status"));
    }

    private int planTarget(ObjectId userId, String weekStart) {
        TrainingPlan plan = mongo.findOne(Query.query(Criteria.where("userId").is(userId)
            .and("weekStart").is(weekStart).and("status").is("active")), TrainingPlan.class);
        return plan == null || plan.targetSessions() == null ? DEFAULT_TARGET : plan.targetSessions();
    }

    private Set<String> ownedAchievements(ObjectId userId) {
        Document user = mongo.findById(userId, Document.class, "users");
        if (user == null) {
            return Set.of();
        }
        return user.getList("achievements", Document.class, List.of()).stream()
            .map(a -> a.getString("code")).collect(Collectors.toSet());
    }

    private List<WorkoutResponse.Record> recordViews(List<Document> records, Map<String, String> names) {
        return records.stream().map(d -> new WorkoutResponse.Record(d.getString("exerciseId"),
            names.get(d.getString("exerciseId")), d.getString("metric"),
            ((Number) d.get("value")).doubleValue(),
            d.get("previous") == null ? null : ((Number) d.get("previous")).doubleValue())).toList();
    }

    private List<WorkoutResponse.Achievement> achievementViews(List<String> codes) {
        if (codes.isEmpty()) {
            return List.of();
        }
        Map<String, Document> catalog = mongo.find(Query.query(Criteria.where("code").in(codes)),
                Document.class, "achievements").stream()
            .collect(Collectors.toMap(d -> d.getString("code"), d -> d));
        return codes.stream().map(code -> {
            Document a = catalog.get(code);
            return new WorkoutResponse.Achievement(code, a == null ? null : a.getString("nameVi"),
                a == null ? null : a.getString("descriptionVi"));
        }).toList();
    }

    private static Document setDocument(WorkoutRequest.SetLog s, Instant now, Set<String> prSets) {
        Document d = new Document("exerciseId", new ObjectId(s.exerciseId()))
            .append("setIndex", s.setIndex())
            .append("isPr", prSets.contains(s.exerciseId() + "#" + s.setIndex()))
            .append("loggedAt", Date.from(now))
            .append("repSource", s.repSource() == null ? "manual" : s.repSource());
        putIfPresent(d, "reps", s.reps());
        putIfPresent(d, "weightKg", s.weightKg());
        putIfPresent(d, "durationSec", s.durationSec());
        putIfPresent(d, "repsDetected", s.repsDetected());
        putIfPresent(d, "cvVersion", s.cvVersion());
        putIfPresent(d, "avgConfidence", s.avgConfidence());
        putIfPresent(d, "formScore", s.formScore());
        if (s.formIssues() != null) {
            d.append("formIssues", s.formIssues().stream().map(i -> new Document("repIndex", i.repIndex())
                .append("code", i.code()).append("severity", i.severity())).toList());
        }
        return d;
    }

    private static void putIfPresent(Document d, String key, Object value) {
        if (value != null) {
            d.append(key, value);
        }
    }

    private static Query byClientId(ObjectId userId, String clientId) {
        return Query.query(Criteria.where("userId").is(userId).and("clientId").is(clientId));
    }

    private static Query weekQuery(ObjectId userId, String weekStart) {
        return Query.query(Criteria.where("userId").is(userId).and("weekStart").is(weekStart));
    }

    private static Query recordQuery(ObjectId userId, WorkoutRules.Best b) {
        return Query.query(Criteria.where("userId").is(userId)
            .and("exerciseId").is(new ObjectId(b.exerciseId())).and("metric").is(b.metric()));
    }
}
