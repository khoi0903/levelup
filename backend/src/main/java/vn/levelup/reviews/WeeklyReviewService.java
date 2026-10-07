package vn.levelup.reviews;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.TreeMap;
import java.util.stream.Collectors;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.server.ResponseStatusException;

import vn.levelup.coach.AiClient;
import vn.levelup.coach.SafeSessions;
import vn.levelup.common.LocalDates;
import vn.levelup.exercises.Exercise;
import vn.levelup.exercises.ExerciseRepository;
import vn.levelup.motivation.WeekClosedListener;
import vn.levelup.notifications.NotificationGateway;
import vn.levelup.plans.ExerciseSwapService;
import vn.levelup.plans.PlanView;
import vn.levelup.plans.TrainingPlan;
import vn.levelup.plans.Week1PlanBuilder;
import vn.levelup.users.User;

/**
 * F6: tổng kết tuần và kế hoạch nháp tuần sau (docs/04-backend-flow.html).
 * Chạy sau khi chốt tuần; chạy lại an toàn: mỗi người mỗi tuần chỉ có một weekly_reviews.
 * AI chỉ viết lời tổng kết; đề xuất tăng/giữ/giảm và kế hoạch do luật cố định quyết.
 */
@Service
public class WeeklyReviewService implements WeekClosedListener {

    private static final Logger log = LoggerFactory.getLogger(WeeklyReviewService.class);

    static final int DEFAULT_TARGET = 3;
    static final int MAX_TOKENS = 600;

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final AiClient ai;
    private final NotificationGateway notifications;
    private final TransactionTemplate tx;
    private final Clock clock;

    public WeeklyReviewService(MongoTemplate mongo, ExerciseRepository exercises, AiClient ai,
                               NotificationGateway notifications, PlatformTransactionManager txManager, Clock clock) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.ai = ai;
        this.notifications = notifications;
        this.tx = new TransactionTemplate(txManager);
        this.clock = clock;
    }

    @Override
    public void onWeekClosed(ObjectId userId, String weekStart) {
        generate(userId, weekStart);
    }

    /** Tạo tổng kết của tuần weekStart (Thứ Hai) và kế hoạch nháp tuần sau; đã có thì trả bản cũ. */
    public Document generate(ObjectId userId, String weekStart) {
        LocalDate start = LocalDates.weekStart(LocalDate.parse(weekStart));
        String ws = start.toString();
        Document existing = findReview(userId, ws);
        if (existing != null) {
            return existing;
        }
        User user = mongo.findById(userId, User.class);
        if (user == null) {
            throw new IllegalArgumentException("Không có người dùng " + userId);
        }
        Instant now = clock.instant();
        String weekEnd = start.plusDays(6).toString();
        LocalDate next = start.plusWeeks(1);
        Map<String, Exercise> byId = new HashMap<>();
        exercises.findAll().forEach(e -> byId.put(e.id(), e));

        // 1. Gom dữ liệu của tuần
        List<Document> logs = mongo.find(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(ws)),
            Document.class, "workout_logs");
        int done = (int) logs.stream().filter(l -> Boolean.TRUE.equals(l.getBoolean("countsForStreak"))).count();
        int totalMinutes = (int) Math.round(logs.stream()
            .mapToDouble(l -> l.get("durationSec") instanceof Number n ? n.doubleValue() : 0).sum() / 60);
        Double avgRpe = logs.stream().filter(l -> l.get("rpe") instanceof Number)
            .mapToDouble(l -> ((Number) l.get("rpe")).doubleValue()).average()
            .stream().boxed().findFirst().map(v -> Math.round(v * 10) / 10.0).orElse(null);
        List<String> prLabels = logs.stream()
            .flatMap(l -> l.getList("newRecords", Document.class, List.of()).stream())
            .map(r -> prLabel(r, byId)).distinct().toList();

        TrainingPlan thisPlan = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(ws)
                .and("status").in("active", "completed")).with(Sort.by(Sort.Direction.DESC, "createdAt")),
            TrainingPlan.class);
        Document streakWeek = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(ws)),
            Document.class, "weekly_streaks");
        int target = thisPlan != null && thisPlan.targetSessions() != null ? thisPlan.targetSessions()
            : streakWeek != null && streakWeek.get("targetSessions") instanceof Number n ? n.intValue()
            : DEFAULT_TARGET;
        String recommendation = ReviewRules.recommendation(done, target, avgRpe);

        List<Document> weights = mongo.find(Query.query(Criteria.where("userId").is(userId)
                .and("measuredOn").gte(ws).lte(weekEnd).and("weightKg").exists(true))
            .with(Sort.by("measuredOn")), Document.class, "body_measurements");
        Double weightChange = weights.size() < 2 ? null : Math.round((num(weights.get(weights.size() - 1), "weightKg")
            - num(weights.get(0), "weightKg")) * 10) / 10.0;

        Map<String, Double> kcalByDay = new TreeMap<>();
        mongo.find(Query.query(Criteria.where("userId").is(userId).and("localDate").gte(ws).lte(weekEnd)),
                Document.class, "meal_logs")
            .forEach(m -> kcalByDay.merge(m.getString("localDate"), num(m, "kcal"), Double::sum));
        Integer avgKcal = kcalByDay.isEmpty() ? null
            : (int) Math.round(kcalByDay.values().stream().mapToDouble(Double::doubleValue).average().orElse(0));

        // 2. Kế hoạch nháp tuần sau, chỉ gồm bài an toàn với chấn thương hiện tại
        List<TrainingPlan.Session> sessions = draftSessions(user, thisPlan, next, recommendation, byId);
        int nextMinutes = sessions.stream().map(TrainingPlan.Session::durationMin).filter(m -> m != null)
            .max(Integer::compare).orElse(ReviewRules.DEFAULT_MINUTES);

        // 3. Lời tổng kết: AI viết, sai hoặc lỗi thì câu mẫu
        String style = user.profile() == null ? null : user.profile().coachStyle();
        ReviewTexts.Facts facts = new ReviewTexts.Facts(user.displayName(), style, done, target, totalMinutes,
            avgRpe, recommendation, prLabels, weightChange, kcalByDay.size(), avgKcal, sessions.size(), nextMinutes);
        Optional<ReviewTexts.Texts> fromAi = askAi(facts);
        ReviewTexts.Texts texts = fromAi.orElseGet(() -> ReviewTexts.fallback(facts));

        ObjectId reviewId = new ObjectId();
        ObjectId planId = new ObjectId();
        TrainingPlan draft = new TrainingPlan(planId.toHexString(), userId, next.toString(), "draft",
            Math.max(1, Math.min(7, sessions.size())), "rule", texts.nextWeekSummary(), sessions, now);
        Document review = new Document("_id", reviewId)
            .append("userId", userId).append("weekStart", ws)
            .append("sessionsDone", done).append("sessionsTarget", target)
            .append("totalMinutes", totalMinutes)
            .append("wins", prLabels.stream().map(l -> new Document("type", "pr").append("label", l)).toList())
            .append("win", texts.win())
            .append("improvement", texts.improve())
            .append("nextWeekSummary", texts.nextWeekSummary())
            .append("recommendation", recommendation)
            .append("proposedPlanId", planId)
            .append("decision", "pending")
            .append("source", fromAi.isPresent() ? "ai" : "rules")
            .append("nutrition", new Document("daysLogged", kcalByDay.size()).append("avgKcal", avgKcal))
            .append("generatedAt", Date.from(now));
        if (avgRpe != null) {
            review.append("avgRpe", avgRpe);
        }
        if (weightChange != null) {
            review.append("weightChangeKg", weightChange);
        }

        try {
            tx.executeWithoutResult(status -> {
                mongo.insert(draft);
                mongo.updateFirst(Query.query(Criteria.where("_id").is(planId)),
                    Update.update("sourceReviewId", reviewId), TrainingPlan.class);
                mongo.insert(review, "weekly_reviews");
            });
        } catch (DataAccessException e) {
            // Hai lần chạy cùng lúc: unique index (userId, weekStart) chặn lần sau, trả bản đã lưu
            Document again = findReview(userId, ws);
            if (again != null) {
                return again;
            }
            throw e;
        }

        notifications.send(userId, "weekly_review", "Tổng kết tuần đã sẵn sàng", texts.win(),
            "review:" + userId.toHexString() + ":" + ws, Map.of("route", "/review", "reviewId", reviewId.toHexString()));
        return review;
    }

    private List<TrainingPlan.Session> draftSessions(User user, TrainingPlan thisPlan, LocalDate next,
                                                     String recommendation, Map<String, Exercise> byId) {
        User.Profile p = user.profile();
        String location = p == null ? null : p.location();
        Set<String> equipment = p == null || p.equipment() == null ? Set.of() : Set.copyOf(p.equipment());
        Set<String> injuries = user.injuries() == null ? Set.of() : user.injuries().stream()
            .filter(i -> !Boolean.FALSE.equals(i.active()) && i.bodyArea() != null)
            .map(User.Injury::bodyArea).collect(Collectors.toSet());
        Set<String> disliked = ExerciseSwapService.dislikes(mongo, new ObjectId(user.id()));
        List<Exercise> safe = SafeSessions.safeList(byId.values(), location, equipment, injuries).stream()
            .filter(e -> !disliked.contains(e.id())).toList();   // bài đã "không gợi ý nữa": makeSafe tự thay

        List<TrainingPlan.Session> sessions = thisPlan == null || thisPlan.sessions() == null ? List.of()
            : ReviewRules.nextWeek(thisPlan.sessions(), next, recommendation);
        if (sessions.isEmpty()) {
            // Tuần này chưa có kế hoạch: lập như tuần đầu, từ Thứ Hai tuần sau
            Map<Integer, String> availability = new LinkedHashMap<>();
            if (user.availability() != null) {
                user.availability().forEach(a -> availability.putIfAbsent(a.weekday(), a.slot()));
            }
            int minutes = p == null || p.sessionMinutes() == null ? ReviewRules.DEFAULT_MINUTES : p.sessionMinutes();
            sessions = Week1PlanBuilder.build(next, availability, minutes, safe).sessions();
        }
        List<TrainingPlan.Session> result = new ArrayList<>();
        for (TrainingPlan.Session s : sessions) {
            List<TrainingPlan.Item> items = SafeSessions.makeSafe(s.items(), byId, safe);
            if (!items.isEmpty()) {
                result.add(new TrainingPlan.Session(s.id(), s.scheduledDate(), s.scheduledTime(), s.title(),
                    s.durationMin(), s.variant(), s.status(), items, s.adjustedReason()));
            }
        }
        return result;
    }

    /** Hỏi Claude; JSON sai thì hỏi lại 1 lần; AI lỗi hoặc vẫn sai thì empty để dùng câu mẫu. */
    private Optional<ReviewTexts.Texts> askAi(ReviewTexts.Facts facts) {
        if (!ai.available()) {
            return Optional.empty();
        }
        String system = ReviewTexts.system(facts.style());
        List<AiClient.Message> messages = List.of(AiClient.Message.user(ReviewTexts.userData(facts)));
        try {
            String raw = ai.complete(system, messages, MAX_TOKENS);
            Optional<ReviewTexts.Texts> parsed = ReviewTexts.parse(raw);
            if (parsed.isPresent()) {
                return parsed;
            }
            List<AiClient.Message> retry = new ArrayList<>(messages);
            retry.add(AiClient.Message.assistant(raw == null || raw.isBlank() ? "{}" : raw));
            retry.add(AiClient.Message.user("Trả lời lại CHỈ bằng JSON hợp lệ có đủ win, improve, nextWeekSummary."));
            return ReviewTexts.parse(ai.complete(system, retry, MAX_TOKENS));
        } catch (RuntimeException e) {
            log.warn("AI tổng kết tuần lỗi, dùng câu mẫu: {}", e.toString());
            return Optional.empty();
        }
    }

    // ------------------------------------------------------------------
    // GET /reviews/latest
    // ------------------------------------------------------------------

    public ReviewViews.ReviewView latest(User user) {
        ObjectId userId = new ObjectId(user.id());
        Document review = mongo.findOne(Query.query(Criteria.where("userId").is(userId))
            .with(Sort.by(Sort.Direction.DESC, "weekStart")), Document.class, "weekly_reviews");
        if (review == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "NO_REVIEW");
        }
        if (review.get("viewedAt") == null) {
            mongo.updateFirst(Query.query(Criteria.where("_id").is(review.getObjectId("_id")).and("viewedAt").exists(false)),
                Update.update("viewedAt", Date.from(clock.instant())), "weekly_reviews");
        }
        return view(review, planView(userId, review.getObjectId("proposedPlanId")));
    }

    // ------------------------------------------------------------------
    // POST /reviews/{id}/decision
    // ------------------------------------------------------------------

    /**
     * Người dùng đồng ý (hoặc chỉnh rồi đồng ý) kế hoạch nháp: nháp thành active, kế hoạch active khác
     * của cùng tuần thành replaced, weekly_streaks của tuần đó có targetSessions bằng kế hoạch.
     */
    @Transactional
    public PlanView decide(User user, String reviewId, ReviewViews.DecisionRequest r) {
        ObjectId userId = new ObjectId(user.id());
        if (reviewId == null || !reviewId.matches("[0-9a-f]{24}")) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "NO_REVIEW");
        }
        boolean adjusted = "adjusted".equals(r.decision());
        if (adjusted && (r.adjustments() == null
                || (r.adjustments().sessionsPerWeek() == null && r.adjustments().sessionMinutes() == null))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "ADJUSTMENTS_REQUIRED");
        }
        Query mine = Query.query(Criteria.where("_id").is(new ObjectId(reviewId)).and("userId").is(userId));
        Document review = mongo.findOne(mine, Document.class, "weekly_reviews");
        if (review == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "NO_REVIEW");
        }
        Instant now = clock.instant();
        // Có điều kiện decision pending: bấm hai lần chỉ áp dụng một lần
        long changed = mongo.updateFirst(Query.query(Criteria.where("_id").is(review.getObjectId("_id"))
                .and("userId").is(userId).and("decision").is("pending")),
            new Update().set("decision", r.decision()).set("decidedAt", Date.from(now)), "weekly_reviews")
            .getModifiedCount();
        if (changed == 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "REVIEW_DECIDED");
        }
        ObjectId planId = review.getObjectId("proposedPlanId");
        TrainingPlan draft = planId == null ? null : mongo.findOne(Query.query(Criteria.where("_id").is(planId)
            .and("userId").is(userId).and("status").is("draft")), TrainingPlan.class);
        if (draft == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "NO_DRAFT_PLAN");
        }

        List<TrainingPlan.Session> sessions = draft.sessions() == null ? List.of() : draft.sessions();
        if (adjusted) {
            sessions = ReviewRules.adjust(sessions, LocalDate.parse(draft.weekStart()),
                r.adjustments().sessionsPerWeek(), r.adjustments().sessionMinutes());
        }
        int target = Math.max(1, Math.min(7, sessions.size()));

        mongo.updateMulti(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(draft.weekStart())
                .and("status").is("active").and("_id").ne(planId)),
            Update.update("status", "replaced"), TrainingPlan.class);
        Update activate = new Update().set("status", "active").set("targetSessions", target);
        if (adjusted) {
            activate.set("createdBy", "user")
                .set("sessions", sessions.stream().map(WeeklyReviewService::sessionDocument).toList());
        }
        mongo.updateFirst(Query.query(Criteria.where("_id").is(planId).and("userId").is(userId)
            .and("status").is("draft")), activate, TrainingPlan.class);

        mongo.upsert(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(draft.weekStart())),
            new Update().set("targetSessions", target)
                .setOnInsert("completedSessions", 0)
                .setOnInsert("status", "in_progress"),
            "weekly_streaks");

        return planView(userId, planId);
    }

    // ------------------------------------------------------------------

    private Document findReview(ObjectId userId, String weekStart) {
        return mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(weekStart)),
            Document.class, "weekly_reviews");
    }

    private PlanView planView(ObjectId userId, ObjectId planId) {
        if (planId == null) {
            return null;
        }
        TrainingPlan plan = mongo.findOne(Query.query(Criteria.where("_id").is(planId).and("userId").is(userId)),
            TrainingPlan.class);
        if (plan == null) {
            return null;
        }
        Set<String> ids = plan.sessions() == null ? Set.of() : plan.sessions().stream()
            .flatMap(s -> s.items() == null ? java.util.stream.Stream.empty() : s.items().stream())
            .map(i -> i.exerciseId().toHexString()).collect(Collectors.toSet());
        Map<String, String> names = new HashMap<>();
        exercises.findAllById(ids).forEach(e -> names.put(e.id(), e.nameVi()));
        return PlanView.of(plan, names);
    }

    private static ReviewViews.ReviewView view(Document d, PlanView plan) {
        int done = intOf(d, "sessionsDone");
        int target = intOf(d, "sessionsTarget");
        List<ReviewViews.Win> wins = d.getList("wins", Document.class, List.of()).stream()
            .map(w -> new ReviewViews.Win(w.getString("type"), w.getString("label"))).toList();
        return new ReviewViews.ReviewView(d.getObjectId("_id").toHexString(), d.getString("weekStart"), done, target,
            ReviewRules.completionPct(done, target), intOf(d, "totalMinutes"),
            d.get("avgRpe") instanceof Number n ? n.doubleValue() : null,
            d.getString("recommendation"), d.getString("win"), wins, d.getString("improvement"),
            d.getString("nextWeekSummary"),
            d.get("weightChangeKg") instanceof Number w ? w.doubleValue() : null,
            d.getString("decision"), d.getString("source"),
            d.getDate("generatedAt") == null ? null : d.getDate("generatedAt").toInstant(), plan);
    }

    private static String prLabel(Document r, Map<String, Exercise> byId) {
        Exercise e = byId.get(String.valueOf(r.get("exerciseId")));
        String name = e == null ? "Bài tập" : e.nameVi();
        double value = num(r, "value");
        String v = value == Math.rint(value) ? String.valueOf((long) value) : String.valueOf(value);
        String unit = switch (String.valueOf(r.getString("metric"))) {
            case "max_weight" -> " kg";
            case "max_duration" -> " giây";
            default -> " lần";
        };
        return name + ": " + v + unit;
    }

    private static Document sessionDocument(TrainingPlan.Session s) {
        Document d = new Document("_id", s.id()).append("scheduledDate", s.scheduledDate())
            .append("title", s.title()).append("durationMin", s.durationMin())
            .append("variant", s.variant() == null ? "normal" : s.variant()).append("status", s.status());
        if (s.scheduledTime() != null) {
            d.append("scheduledTime", s.scheduledTime());
        }
        d.append("items", s.items() == null ? List.of() : s.items().stream().map(i -> {
            Document item = new Document("exerciseId", i.exerciseId());
            if (i.targetSets() != null) {
                item.append("targetSets", i.targetSets());
            }
            if (i.targetReps() != null) {
                item.append("targetReps", i.targetReps());
            }
            if (i.targetDurationSec() != null) {
                item.append("targetDurationSec", i.targetDurationSec());
            }
            if (i.restSec() != null) {
                item.append("restSec", i.restSec());
            }
            return item;
        }).toList());
        return d;
    }

    private static double num(Document d, String key) {
        return d.get(key) instanceof Number n ? n.doubleValue() : 0;
    }

    private static int intOf(Document d, String key) {
        return d.get(key) instanceof Number n ? n.intValue() : 0;
    }
}
