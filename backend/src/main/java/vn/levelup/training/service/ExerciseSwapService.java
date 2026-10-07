package vn.levelup.training.service;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
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

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import vn.levelup.coach.rules.SafeSessions;
import vn.levelup.identity.model.User;
import vn.levelup.training.dto.PlanView;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.repository.ExerciseRepository;
import vn.levelup.training.rules.ExerciseFilter;

/**
 * Người dùng tự đổi bài không thích trong một buổi còn planned (gợi ý bài tương tự, an toàn với họ).
 * "Không gợi ý bài này nữa": lưu users.exerciseDislikes, các kế hoạch tuần sau tự thay bài đó.
 */
@Service
public class ExerciseSwapService {

    public static final int MAX_ALTERNATIVES = 6;

    private final MongoTemplate mongo;
    private final PlanReader plans;
    private final ExerciseRepository exercises;

    public ExerciseSwapService(MongoTemplate mongo, PlanReader plans, ExerciseRepository exercises) {
        this.mongo = mongo;
        this.plans = plans;
        this.exercises = exercises;
    }

    /** reason: lý do ngắn tiếng Việt để app hiện dưới tên bài ("Cùng nhóm cơ · Không cần dụng cụ"). */
    public record Alternative(String exerciseId, String nameVi, String primaryMuscle, String tracking,
                              boolean cameraSupported, String reason) {}

    public record SwapRequest(
        @NotNull @Pattern(regexp = "[0-9a-f]{24}") String fromExerciseId,
        @NotNull @Pattern(regexp = "[0-9a-f]{24}") String toExerciseId,
        Boolean remember
    ) {}

    /** Bài thay thế cho fromExerciseId trong buổi: an toàn, chưa có trong buổi, không phải bài người dùng đã bỏ. */
    public List<Alternative> alternatives(User user, String sessionHex, String fromHex) {
        Ctx c = load(user, sessionHex, fromHex);
        Exercise from = c.byId().get(fromHex);
        return rank(c.candidates(), from).stream().limit(MAX_ALTERNATIVES)
            .map(e -> new Alternative(e.id(), e.nameVi(), e.primaryMuscle(), e.tracking(), camera(e), reason(e, from)))
            .toList();
    }

    public PlanView swap(User user, String sessionHex, SwapRequest r) {
        Ctx c = load(user, sessionHex, r.fromExerciseId());
        Exercise to = c.candidates().stream().filter(e -> e.id().equals(r.toExerciseId())).findFirst()
            .orElseThrow(() -> new ResponseStatusException(HttpStatus.BAD_REQUEST, "EXERCISE_NOT_ALLOWED"));
        List<Document> items = c.session().items().stream()
            .map(i -> i.exerciseId().toHexString().equals(r.fromExerciseId()) ? SafeSessions.replaceItem(i, to) : i)
            .map(PlanSessionService::itemDocument)
            .toList();
        var result = mongo.updateFirst(PlanSessionService.plannedSession(c.plan(), c.userId(), c.session().id()),
            new Update().set("sessions.$.items", items).set("sessions.$.adjustedReason", "user_swap"),
            TrainingPlan.class);
        if (result.getMatchedCount() == 0) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "SESSION_NOT_PLANNED");
        }
        if (Boolean.TRUE.equals(r.remember())) {
            mongo.updateFirst(Query.query(Criteria.where("_id").is(c.userId())),
                new Update().addToSet("exerciseDislikes", new ObjectId(r.fromExerciseId())), "users");
        }
        return plans.view(plans.byId(c.plan().id()));
    }

    /** id các bài người dùng chọn "Không gợi ý bài này nữa" (để lập kế hoạch tuần sau loại ra). */
    public static Set<String> dislikes(MongoTemplate mongo, ObjectId userId) {
        Document u = mongo.findById(userId, Document.class, "users");
        if (u == null) {
            return Set.of();
        }
        return u.getList("exerciseDislikes", ObjectId.class, List.of()).stream()
            .map(ObjectId::toHexString).collect(Collectors.toSet());
    }

    /** Ưu tiên: cùng nhóm cơ, cùng kiểu đếm, đếm được bằng camera, độ khó gần nhất. */
    static List<Exercise> rank(List<Exercise> candidates, Exercise from) {
        String muscle = from == null ? null : from.primaryMuscle();
        String tracking = from == null ? null : from.tracking();
        int difficulty = from == null ? 1 : from.difficultyOrDefault();
        return candidates.stream().sorted(Comparator
                .comparingInt((Exercise e) -> muscle != null && muscle.equals(e.primaryMuscle()) ? 0 : 1)
                .thenComparingInt(e -> tracking != null && tracking.equals(e.tracking()) ? 0 : 1)
                .thenComparingInt(e -> camera(e) ? 0 : 1)
                .thenComparingInt(e -> Math.abs(e.difficultyOrDefault() - difficulty))
                .thenComparing(Exercise::nameVi, Comparator.nullsLast(Comparator.naturalOrder())))
            .toList();
    }

    static String reason(Exercise e, Exercise from) {
        List<String> parts = new ArrayList<>();
        if (from != null && from.primaryMuscle() != null && from.primaryMuscle().equals(e.primaryMuscle())) {
            parts.add("Cùng nhóm cơ");
        }
        if (e.equipment() == null || e.equipment().isEmpty()) {
            parts.add("Không cần dụng cụ");
        }
        if (camera(e)) {
            parts.add("Đếm được bằng camera");
        }
        return String.join(" · ", parts);
    }

    private static boolean camera(Exercise e) {
        return e.cv() != null && Boolean.TRUE.equals(e.cv().supported());
    }

    private record Ctx(ObjectId userId, TrainingPlan plan, TrainingPlan.Session session, Map<String, Exercise> byId,
                       List<Exercise> candidates) {}

    private Ctx load(User user, String sessionHex, String fromHex) {
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
        List<TrainingPlan.Item> items = session.items() == null ? List.of() : session.items();
        Set<String> inSession = items.stream().map(i -> i.exerciseId().toHexString()).collect(Collectors.toSet());
        if (!inSession.contains(fromHex)) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "EXERCISE_NOT_IN_SESSION");
        }
        List<Exercise> active = exercises.findByIsActiveTrue();
        Map<String, Exercise> byId = active.stream().collect(Collectors.toMap(Exercise::id, Function.identity()));
        User.Profile p = user.profile();
        Set<String> equipment = p == null || p.equipment() == null ? Set.of() : Set.copyOf(p.equipment());
        Set<String> injuries = user.injuries() == null ? Set.of() : user.injuries().stream()
            .filter(i -> !Boolean.FALSE.equals(i.active())).map(User.Injury::bodyArea).collect(Collectors.toSet());
        Set<String> exclude = new HashSet<>(inSession);
        exclude.addAll(dislikes(mongo, userId));
        List<Exercise> candidates = ExerciseFilter.forUser(active, p == null ? null : p.location(), equipment, injuries)
            .stream().filter(e -> !exclude.contains(e.id())).toList();
        return new Ctx(userId, plan, session, byId, candidates);
    }
}
