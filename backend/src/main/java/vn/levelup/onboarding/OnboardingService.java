package vn.levelup.onboarding;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

import vn.levelup.common.LocalDates;
import vn.levelup.exercises.Exercise;
import vn.levelup.exercises.ExerciseFilter;
import vn.levelup.exercises.ExerciseRepository;
import vn.levelup.nutrition.NutritionCalculator;
import vn.levelup.plans.PlanView;
import vn.levelup.plans.TrainingPlan;
import vn.levelup.plans.Week1PlanBuilder;
import vn.levelup.users.User;

/**
 * F1: lưu khảo sát, tính mục tiêu calo, tạo kế hoạch tuần 1 và streak tuần này.
 * Chạy trong một transaction: hoặc lưu đủ, hoặc không lưu gì.
 * Làm lại onboarding thì cập nhật hồ sơ và thay kế hoạch tuần đó.
 */
@Service
public class OnboardingService {

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final Clock clock;

    public OnboardingService(MongoTemplate mongo, ExerciseRepository exercises, Clock clock) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.clock = clock;
    }

    @Transactional
    public OnboardingResponse complete(String uid, OnboardingRequest r) {
        ZoneId zone = LocalDates.zone(r.timezone());
        LocalDate today = LocalDates.today(zone.getId(), clock);
        Instant now = clock.instant();

        List<String> equipment = r.equipment() == null ? List.of() : r.equipment().stream().distinct().toList();
        List<String> injuryAreas = r.injuries() == null ? List.of() : r.injuries().stream().distinct().toList();
        List<User.Injury> injuries = injuryAreas.stream().map(a -> new User.Injury(a, null, true, now)).toList();
        Map<Integer, String> availability = new LinkedHashMap<>();
        r.availability().stream()
            .sorted((a, b) -> a.weekday().compareTo(b.weekday()))
            .forEach(s -> availability.putIfAbsent(s.weekday(), s.slot()));

        User.Profile profile = new User.Profile(r.goal(), r.gender(), r.birthYear(), r.heightCm(), r.weightKg(),
            r.goalWeightKg(), r.experience(), r.location(), r.sessionMinutes(), r.coachStyle(),
            r.motivationReasons(), r.motivationText(), equipment, now);
        User.NutritionTarget target = NutritionCalculator.compute(
            r.gender(), r.birthYear(), r.heightCm(), r.weightKg(), r.goal(), today);

        // 1. Hồ sơ người dùng ($set từng trường để không xóa dữ liệu khác)
        Query byUid = Query.query(Criteria.where("authUid").is(uid));
        Update userUpdate = new Update()
            .set("displayName", r.displayName().trim())
            .set("timezone", zone.getId())
            .set("profile", profile)
            .set("injuries", injuries)
            .set("availability", availability.entrySet().stream()
                .map(e -> new User.Availability(e.getKey(), e.getValue())).toList())
            .set("lastActiveAt", now)
            .push("nutritionTargets", target)
            .setOnInsert("authUid", uid)
            .setOnInsert("locale", "vi")
            .setOnInsert("createdAt", now)
            .setOnInsert("streak", new User.Streak(0, 0, 0, null));
        mongo.upsert(byUid, userUpdate, User.class);
        User user = mongo.findOne(byUid, User.class);
        ObjectId userId = new ObjectId(user.id());

        // 2. Kế hoạch tuần 1 từ bài an toàn với người dùng.
        // Kho bài tập trống (database mới chưa nạp seed) thì báo lỗi, không tạo kế hoạch 0 động tác.
        List<Exercise> catalog = exercises.findByIsActiveTrue();
        if (catalog.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "EXERCISE_CATALOG_EMPTY");
        }
        List<Exercise> safe = ExerciseFilter.forUser(catalog, r.location(),
            Set.copyOf(equipment), Set.copyOf(injuryAreas));
        Week1PlanBuilder.Draft draft = Week1PlanBuilder.build(today, availability, r.sessionMinutes(), safe);
        String weekStart = draft.weekStart().toString();

        mongo.updateMulti(
            Query.query(Criteria.where("userId").is(userId).and("weekStart").is(weekStart).and("status").is("active")),
            Update.update("status", "replaced"), TrainingPlan.class);
        TrainingPlan plan = mongo.insert(new TrainingPlan(null, userId, weekStart, "active",
            Math.max(1, draft.sessions().size()), "rule", null, draft.sessions(), now));

        // 3. Streak của tuần có kế hoạch
        mongo.upsert(
            Query.query(Criteria.where("userId").is(userId).and("weekStart").is(weekStart)),
            new Update()
                .set("targetSessions", plan.targetSessions())
                .setOnInsert("completedSessions", 0)
                .setOnInsert("status", "in_progress"),
            "weekly_streaks");

        Map<String, String> names = safe.stream().collect(Collectors.toMap(Exercise::id, Exercise::nameVi));
        return new OnboardingResponse(user.id(), user.displayName(), target, PlanView.of(plan, names));
    }

    public record OnboardingResponse(
        String userId,
        String displayName,
        User.NutritionTarget nutritionTarget,
        PlanView plan
    ) {}
}
