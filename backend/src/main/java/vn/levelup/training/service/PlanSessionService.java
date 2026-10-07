package vn.levelup.training.service;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import vn.levelup.identity.model.User;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.PlanView;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.rules.SessionRules;

/** PATCH /plans/sessions/{id}: dời lịch, đổi sang bản 5 phút, đánh dấu nghỉ (F2, F3). */
@Service
public class PlanSessionService {

    private final MongoTemplate mongo;
    private final PlanReader plans;
    private final Clock clock;

    public PlanSessionService(MongoTemplate mongo, PlanReader plans, Clock clock) {
        this.mongo = mongo;
        this.plans = plans;
        this.clock = clock;
    }

    public record PatchRequest(
        @NotNull @Pattern(regexp = "reschedule|quick5|rest") String action,
        @Pattern(regexp = "\\d{4}-\\d{2}-\\d{2}") String scheduledDate,
        @Pattern(regexp = "([01]\\d|2[0-3]):[0-5]\\d") String scheduledTime
    ) {}

    public PlanView patch(User user, String sessionHex, PatchRequest r) {
        if (!ObjectId.isValid(sessionHex)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "SESSION_NOT_FOUND");
        }
        ObjectId userId = new ObjectId(user.id());
        ObjectId sessionId = new ObjectId(sessionHex);
        TrainingPlan plan = plans.activeWithSession(userId, sessionId);
        if (plan == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "SESSION_NOT_FOUND");
        }
        TrainingPlan.Session session = plan.sessions().stream().filter(s -> sessionId.equals(s.id()))
            .findFirst().orElseThrow();
        if (!"planned".equals(session.status())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "SESSION_NOT_PLANNED");
        }

        Update update = new Update();
        switch (r.action()) {
            case "reschedule" -> {
                if (r.scheduledDate() == null && r.scheduledTime() == null) {
                    throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "SCHEDULED_DATE_REQUIRED");
                }
                if (r.scheduledDate() != null) {
                    LocalDate target = LocalDate.parse(r.scheduledDate());
                    String error = SessionRules.rescheduleError(LocalDate.parse(plan.weekStart()),
                        LocalDates.today(user.timezone(), clock), target);
                    if (error != null) {
                        throw new ResponseStatusException(HttpStatus.BAD_REQUEST, error);
                    }
                    update.set("sessions.$.scheduledDate", target.toString());
                }
                if (r.scheduledTime() != null) {
                    update.set("sessions.$.scheduledTime", r.scheduledTime());
                }
                update.set("sessions.$.adjustedReason", "user_reschedule");
            }
            case "quick5" -> {
                List<TrainingPlan.Item> items = SessionRules.quick5(
                    session.items() == null ? List.of() : session.items());
                update.set("sessions.$.variant", "quick5")
                    .set("sessions.$.durationMin", SessionRules.QUICK5_SEC / 60)
                    .set("sessions.$.items", items.stream().map(PlanSessionService::itemDocument).toList())
                    .set("sessions.$.adjustedReason", "user_quick5");
            }
            case "rest" -> update.set("sessions.$.status", "rest").set("sessions.$.adjustedReason", "user_rest");
            default -> throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "UNKNOWN_ACTION");
        }

        var result = mongo.updateFirst(plannedSession(plan, userId, sessionId), update, TrainingPlan.class);
        if (result.getMatchedCount() == 0) {
            // Buổi vừa được lưu hoặc đổi ở request khác
            throw new ResponseStatusException(HttpStatus.CONFLICT, "SESSION_NOT_PLANNED");
        }
        return plans.view(plans.byId(plan.id()));
    }

    /** Buổi còn planned trong kế hoạch active của chính người dùng, để cập nhật bằng sessions.$. */
    public static Query plannedSession(TrainingPlan plan, ObjectId userId, ObjectId sessionId) {
        return Query.query(Criteria.where("_id").is(new ObjectId(plan.id())).and("userId").is(userId)
            .and("status").is("active")
            .and("sessions").elemMatch(Criteria.where("_id").is(sessionId).and("status").is("planned")));
    }

    /** Một động tác dạng Document, chỉ ghi trường có giá trị (validator không nhận null). */
    public static Document itemDocument(TrainingPlan.Item i) {
        Document d = new Document("exerciseId", i.exerciseId());
        if (i.targetSets() != null) {
            d.append("targetSets", i.targetSets());
        }
        if (i.targetReps() != null) {
            d.append("targetReps", i.targetReps());
        }
        if (i.targetDurationSec() != null) {
            d.append("targetDurationSec", i.targetDurationSec());
        }
        if (i.restSec() != null) {
            d.append("restSec", i.restSec());
        }
        return d;
    }
}
