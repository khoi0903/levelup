package vn.levelup.engagement.service;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import vn.levelup.coach.rules.CoachRules;
import vn.levelup.engagement.notification.NotificationGateway;
import vn.levelup.engagement.rules.SkipPlanner;
import vn.levelup.identity.model.User;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.PlanView;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.repository.ExerciseRepository;
import vn.levelup.training.rules.ExerciseFilter;
import vn.levelup.training.rules.PainRules;
import vn.levelup.training.service.PlanReader;
import vn.levelup.training.service.PlanSessionService;

/**
 * Hỏi thăm vùng đau nhói báo sau buổi tập (PainRules): ghi vào theo dõi, hỏi lại từ hôm sau,
 * hết đau thì bỏ, còn đau thì tiếp tục tránh vùng đó, lâu không đỡ hoặc đau hơn thì thành chấn thương.
 */
@Service
public class PainFollowUpService {

    /** Không gửi hỏi thăm trước giờ này theo giờ người dùng (giờ yên lặng tới 07:00, chừa thêm 1 tiếng). */
    static final int REMIND_FROM_HOUR = 8;

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final PlanReader plans;
    private final NotificationGateway notifications;
    private final Clock clock;

    public PainFollowUpService(MongoTemplate mongo, ExerciseRepository exercises, PlanReader plans,
                               NotificationGateway notifications, Clock clock) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.plans = plans;
        this.notifications = notifications;
        this.clock = clock;
    }

    /** Một vùng cần hỏi thăm hôm nay, cho thẻ ở Trang chủ (GET /me). */
    public record FollowUpView(String bodyArea, String label, String reportedOn, long days) {}

    /** status: resolved | monitoring | injury. plan: kế hoạch tuần sau khi đổi bài (null nếu chưa có). */
    public record AnswerResponse(String status, String message, PlanView plan) {}

    public List<FollowUpView> due(User user, LocalDate today) {
        return watches(user).stream().filter(w -> PainRules.isDue(w, today))
            .map(w -> new FollowUpView(w.bodyArea(), CoachRules.areaVi(w.bodyArea()), w.reportedOn().toString(),
                PainRules.daysSince(w, today)))
            .toList();
    }

    /**
     * Sau buổi tập báo đau nhói: vùng chưa có thì thêm vào injuries (active, followUp), vùng đang theo dõi thì
     * tính lại từ hôm nay; vùng đã là chấn thương thì để nguyên. Rồi đổi bài ở các buổi còn lại.
     */
    public void startWatch(User user, LocalDate today, List<String> areas) {
        ObjectId userId = new ObjectId(user.id());
        List<User.Injury> injuries = user.injuries() == null ? List.of() : user.injuries();
        for (String area : areas.stream().distinct().toList()) {
            User.Injury current = injuries.stream()
                .filter(i -> area.equals(i.bodyArea()) && !Boolean.FALSE.equals(i.active()))
                .findFirst().orElse(null);
            if (current != null && !Boolean.TRUE.equals(current.followUp())) {
                continue;
            }
            if (current != null) {
                mongo.updateFirst(watchQuery(userId, area), new Update()
                    .set("injuries.$.reportedOn", today.toString())
                    .unset("injuries.$.lastAnswer").unset("injuries.$.lastAnswerOn"), "users");
            } else {
                mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)), new Update().push("injuries",
                    new Document("bodyArea", area).append("active", true).append("followUp", true)
                        .append("reportedOn", today.toString()).append("reportedAt", Date.from(clock.instant()))),
                    "users");
            }
            avoidArea(user, area, today);
        }
    }

    /** Vùng đang bị tránh khi chọn bài (chấn thương hoặc đang theo dõi), cho mục "Đã khỏi" trong app. */
    public record ActiveInjuryView(String bodyArea, String label, boolean followUp) {}

    public List<ActiveInjuryView> activeInjuries(User user) {
        return user.injuries() == null ? List.of() : user.injuries().stream()
            .filter(i -> !Boolean.FALSE.equals(i.active()))
            .map(i -> new ActiveInjuryView(i.bodyArea(), CoachRules.areaVi(i.bodyArea()),
                Boolean.TRUE.equals(i.followUp())))
            .toList();
    }

    /**
     * POST /pain-followups/{bodyArea}: người dùng trả lời hỏi thăm. Riêng "gone" dùng được cho mọi vùng đang
     * tránh (kể cả chấn thương từ onboarding, coach hay hỏi thăm trước đó) để người dùng báo đã khỏi.
     */
    public AnswerResponse answer(User user, String bodyArea, String answer) {
        ObjectId userId = new ObjectId(user.id());
        LocalDate today = LocalDates.today(user.timezone(), clock);
        PainRules.Watch watch = watches(user).stream().filter(w -> w.bodyArea().equals(bodyArea)).findFirst()
            .orElse(null);
        if (watch == null) {
            boolean injured = activeInjuries(user).stream().anyMatch(i -> i.bodyArea().equals(bodyArea));
            if (!injured || !"gone".equals(answer)) {
                throw new ResponseStatusException(HttpStatus.NOT_FOUND, "PAIN_FOLLOWUP_NOT_FOUND");
            }
            mongo.updateFirst(Query.query(Criteria.where("_id").is(userId).and("injuries").elemMatch(
                    Criteria.where("bodyArea").is(bodyArea).and("active").is(true))),
                new Update().set("injuries.$.active", false).set("injuries.$.followUp", false)
                    .set("injuries.$.resolvedAt", Date.from(clock.instant())), "users");
            TrainingPlan plan = plans.current(userId, today);
            return new AnswerResponse("resolved", PainRules.answer(new PainRules.Watch(bodyArea, today, null, null),
                "gone", today, CoachRules.areaVi(bodyArea)).message(), plan == null ? null : plans.view(plan));
        }
        PainRules.Decision decision = PainRules.answer(watch, answer, today, CoachRules.areaVi(bodyArea));

        Update update = new Update().set("injuries.$.lastAnswer", answer)
            .set("injuries.$.lastAnswerOn", today.toString());
        switch (decision.status()) {
            case RESOLVED -> update.set("injuries.$.active", false).set("injuries.$.followUp", false)
                .set("injuries.$.resolvedAt", Date.from(clock.instant()));
            case INJURY -> update.set("injuries.$.followUp", false);
            case MONITORING -> { }
        }
        mongo.updateFirst(watchQuery(userId, bodyArea), update, "users");
        if (decision.status() != PainRules.Status.RESOLVED) {
            avoidArea(user, bodyArea, today);
        }
        TrainingPlan plan = plans.current(userId, today);
        return new AnswerResponse(decision.status().name().toLowerCase(), decision.message(),
            plan == null ? null : plans.view(plan));
    }

    /** Job mỗi 10 phút: buổi sáng gửi một tin hỏi thăm cho các vùng cần hỏi hôm nay (dedupe theo ngày). */
    public int remind(ObjectId userId, LocalDateTime local) {
        if (local.getHour() < REMIND_FROM_HOUR) {
            return 0;
        }
        User user = mongo.findById(userId, User.class);
        if (user == null) {
            return 0;
        }
        LocalDate today = local.toLocalDate();
        List<FollowUpView> due = due(user, today);
        if (due.isEmpty()) {
            return 0;
        }
        String areas = due.stream().map(FollowUpView::label).collect(Collectors.joining(", "));
        String title = due.size() == 1 ? capitalize(areas) + " hôm nay sao rồi?" : "Hôm nay còn đau không?";
        String body = "Hôm qua bạn báo đau " + areas + ". Bấm để cho mình biết, mình chỉnh buổi tập hôm nay cho hợp.";
        NotificationGateway.Result r = notifications.send(userId, "pain_followup", title, body,
            "pain:" + userId.toHexString() + ":" + today, Map.of("route", "/home"));
        return r == NotificationGateway.Result.SENT ? 1 : 0;
    }

    /** Đổi bài có chống chỉ định trùng vùng này ở các buổi planned từ hôm nay (giống bỏ buổi vì đau). */
    void avoidArea(User user, String area, LocalDate today) {
        ObjectId userId = new ObjectId(user.id());
        TrainingPlan plan = plans.current(userId, today);
        if (plan == null) {
            return;
        }
        List<Exercise> active = exercises.findByIsActiveTrue();
        Map<String, Exercise> catalog = active.stream()
            .collect(Collectors.toMap(Exercise::id, Function.identity(), (a, b) -> a));
        User.Profile profile = user.profile();
        Set<String> injuries = new java.util.HashSet<>(activeAreas(user));
        injuries.add(area);
        List<Exercise> safe = ExerciseFilter.forUser(active, profile == null ? null : profile.location(),
            Set.copyOf(profile == null || profile.equipment() == null ? List.of() : profile.equipment()), injuries);
        SkipPlanner.Outcome outcome = SkipPlanner.plan("pain", plan.sessions(), today,
            LocalDate.parse(plan.weekStart()), null, area, catalog, safe);
        for (TrainingPlan.Session s : outcome.changed()) {
            mongo.updateFirst(PlanSessionService.plannedSession(plan, userId, s.id()), new Update()
                .set("sessions.$.status", s.status())
                .set("sessions.$.items", s.items().stream().map(PlanSessionService::itemDocument).toList())
                .set("sessions.$.adjustedReason", s.adjustedReason()), TrainingPlan.class);
        }
    }

    static List<PainRules.Watch> watches(User user) {
        List<PainRules.Watch> out = new ArrayList<>();
        if (user.injuries() == null) {
            return out;
        }
        for (User.Injury i : user.injuries()) {
            if (Boolean.TRUE.equals(i.followUp()) && !Boolean.FALSE.equals(i.active()) && i.reportedOn() != null) {
                out.add(new PainRules.Watch(i.bodyArea(), LocalDate.parse(i.reportedOn()), i.lastAnswer(),
                    i.lastAnswerOn() == null ? null : LocalDate.parse(i.lastAnswerOn())));
            }
        }
        return out;
    }

    private static Set<String> activeAreas(User user) {
        return user.injuries() == null ? Set.of() : user.injuries().stream()
            .filter(i -> !Boolean.FALSE.equals(i.active())).map(User.Injury::bodyArea).collect(Collectors.toSet());
    }

    private static Query watchQuery(ObjectId userId, String area) {
        return Query.query(Criteria.where("_id").is(userId).and("injuries").elemMatch(
            Criteria.where("bodyArea").is(area).and("active").is(true).and("followUp").is(true)));
    }

    private static String capitalize(String s) {
        return s.isEmpty() ? s : Character.toUpperCase(s.charAt(0)) + s.substring(1);
    }
}
