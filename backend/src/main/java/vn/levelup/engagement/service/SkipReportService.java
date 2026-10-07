package vn.levelup.engagement.service;

import java.time.Clock;
import java.time.LocalDate;
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
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import vn.levelup.engagement.rules.SkipPlanner;
import vn.levelup.identity.model.User;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.PlanView;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.repository.ExerciseRepository;
import vn.levelup.training.rules.ExerciseFilter;
import vn.levelup.training.service.PlanReader;
import vn.levelup.training.service.PlanSessionService;

/** F3: người dùng cho biết lý do bỏ buổi, API điều chỉnh kế hoạch theo bảng lý do. */
@Service
public class SkipReportService {

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final PlanReader plans;
    private final CoachTemplates templates;
    private final Clock clock;

    public SkipReportService(MongoTemplate mongo, ExerciseRepository exercises, PlanReader plans,
                             CoachTemplates templates, Clock clock) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.plans = plans;
        this.templates = templates;
        this.clock = clock;
    }

    public record SkipReportRequest(
        @Pattern(regexp = "[0-9a-f]{24}") String plannedSessionId,
        @NotNull @Pattern(regexp = "busy|tired|pain|bored|forgot|other") String reason,
        @Size(max = 500) String note,
        @Pattern(regexp = "lower_back|knee|shoulder|neck|wrist|ankle|hip|other") String bodyArea
    ) {}

    /**
     * @param action     giá trị skip_reports.action (shortened, reduced_intensity, swapped_exercises...)
     * @param suggestion chỉ có khi reason = forgot: cài đặt nhắc đề xuất, app hỏi người dùng rồi tự lưu
     */
    public record SkipReportResponse(String action, PlanView plan, String message, Map<String, Object> suggestion) {}

    @Transactional
    public SkipReportResponse report(User user, SkipReportRequest r) {
        if ("pain".equals(r.reason()) && r.bodyArea() == null) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "BODY_AREA_REQUIRED");
        }
        ObjectId userId = new ObjectId(user.id());
        LocalDate today = LocalDates.today(user.timezone(), clock);
        ObjectId plannedSessionId = r.plannedSessionId() == null ? null : new ObjectId(r.plannedSessionId());

        // Vùng đau mới vào users.injuries trước, để bài thay thế được lọc theo cả vùng này
        Set<String> injuries = activeInjuries(user);
        if ("pain".equals(r.reason()) && !injuries.contains(r.bodyArea())) {
            Document injury = new Document("bodyArea", r.bodyArea()).append("active", true)
                .append("reportedAt", Date.from(clock.instant()));
            if (r.note() != null) {
                injury.append("note", r.note());
            }
            mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)), new Update().push("injuries", injury),
                "users");
        }

        TrainingPlan plan = plannedSessionId == null ? null : plans.activeWithSession(userId, plannedSessionId);
        if (plan == null) {
            plan = plans.current(userId, today);
        }

        SkipPlanner.Outcome outcome = new SkipPlanner.Outcome("none", List.of(), null);
        if (plan != null || "forgot".equals(r.reason())) {
            List<TrainingPlan.Session> sessions = plan == null ? List.of() : plan.sessions();
            List<Exercise> active = exercises.findByIsActiveTrue();
            Map<String, Exercise> catalog = active.stream()
                .collect(Collectors.toMap(Exercise::id, Function.identity(), (a, b) -> a));
            User.Profile profile = user.profile();
            List<Exercise> safe = ExerciseFilter.forUser(active, profile == null ? null : profile.location(),
                Set.copyOf(profile == null || profile.equipment() == null ? List.of() : profile.equipment()),
                SkipPlanner.withArea(injuries, r.bodyArea()));
            outcome = SkipPlanner.plan(r.reason(), sessions, today,
                plan == null ? LocalDates.weekStart(today) : LocalDate.parse(plan.weekStart()),
                plannedSessionId, r.bodyArea(), catalog, safe);
        }

        for (TrainingPlan.Session s : outcome.changed()) {
            Update update = new Update()
                .set("sessions.$.scheduledDate", s.scheduledDate())
                .set("sessions.$.variant", s.variant())
                .set("sessions.$.status", s.status())
                .set("sessions.$.items", s.items().stream().map(PlanSessionService::itemDocument).toList())
                .set("sessions.$.adjustedReason", s.adjustedReason());
            if (s.durationMin() != null) {
                update.set("sessions.$.durationMin", s.durationMin());
            }
            mongo.updateFirst(PlanSessionService.plannedSession(plan, userId, s.id()), update, TrainingPlan.class);
        }

        Document report = new Document("userId", userId)
            .append("reason", r.reason())
            .append("action", outcome.action())
            .append("createdAt", Date.from(clock.instant()));
        if (plan != null) {
            report.append("planId", new ObjectId(plan.id()));
        }
        if (plannedSessionId != null) {
            report.append("plannedSessionId", plannedSessionId);
        }
        if (r.note() != null) {
            report.append("note", r.note());
        }
        if (r.bodyArea() != null) {
            report.append("bodyArea", r.bodyArea());
        }
        mongo.insert(report, "skip_reports");

        String message = message(user, r.reason(), outcome.action(), today.toString());
        return new SkipReportResponse(outcome.action(), plan == null ? null : plans.view(plans.byId(plan.id())),
            message, outcome.suggestion());
    }

    private String message(User user, String reason, String action, String seed) {
        String name = user.displayName() == null ? "" : user.displayName();
        String style = user.profile() == null ? null : user.profile().coachStyle();
        return templates.render("skip_" + reason, style, Map.of("ten", name), seed)
            .orElseGet(() -> fallback(name, reason, action));
    }

    /** Câu mặc định khi docs/content/coach-messages.json chưa có mẫu cho lý do này. */
    static String fallback(String name, String reason, String action) {
        String hi = name.isBlank() ? "" : name + ", ";
        return switch (reason) {
            case "busy" -> "none".equals(action)
                ? hi + "tuần này không còn buổi nào cần dời. Khi rảnh, thử bản 5 phút nhé."
                : hi + "mình rút buổi tới còn 10 phút và dời buổi sau sang ngày trống.";
            case "tired" -> hi + "mình giảm cường độ các buổi còn lại trong tuần. Nghỉ ngơi đủ cũng là tập luyện.";
            case "pain" -> hi + "mình đã đổi sang bài an toàn cho vùng đau. Nếu đau kéo dài, bạn nên đi khám nhé.";
            case "bored" -> hi + "mình đổi sang bài mới cùng nhóm cơ cho các buổi còn lại.";
            case "forgot" -> hi + "bật nhắc trước buổi tập 60 phút nhé? Bạn có thể đổi trong cài đặt thông báo.";
            default -> hi + "cảm ơn bạn đã chia sẻ. Kế hoạch vẫn giữ nguyên, tập khi bạn sẵn sàng nhé.";
        };
    }

    private static Set<String> activeInjuries(User user) {
        return user.injuries() == null ? Set.of() : user.injuries().stream()
            .filter(i -> !Boolean.FALSE.equals(i.active()))
            .map(User.Injury::bodyArea)
            .collect(Collectors.toSet());
    }
}
