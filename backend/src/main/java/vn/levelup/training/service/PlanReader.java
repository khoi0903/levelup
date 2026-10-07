package vn.levelup.training.service;

import java.time.LocalDate;
import java.util.Map;
import java.util.Objects;
import java.util.stream.Collectors;
import java.util.stream.Stream;
import java.util.stream.StreamSupport;

import org.bson.types.ObjectId;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Service;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.PlanView;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.repository.ExerciseRepository;


/** Đọc kế hoạch đang áp dụng và dựng PlanView, dùng chung cho plans, motivation, workouts, jobs. */
@Service
public class PlanReader {

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;

    public PlanReader(MongoTemplate mongo, ExerciseRepository exercises) {
        this.mongo = mongo;
        this.exercises = exercises;
    }

    /** Kế hoạch active của tuần chứa ngày này; chưa có thì kế hoạch active gần nhất sau đó. */
    public TrainingPlan current(ObjectId userId, LocalDate today) {
        String thisWeek = LocalDates.weekStart(today).toString();
        TrainingPlan plan = mongo.findOne(Query.query(Criteria.where("userId").is(userId)
            .and("status").is("active").and("weekStart").is(thisWeek)), TrainingPlan.class);
        if (plan != null) {
            return plan;
        }
        return mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("status").is("active")
            .and("weekStart").gt(thisWeek)).with(Sort.by("weekStart")), TrainingPlan.class);
    }

    /** Kế hoạch active của người dùng có chứa buổi này. */
    public TrainingPlan activeWithSession(ObjectId userId, ObjectId sessionId) {
        return mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("status").is("active")
            .and("sessions._id").is(sessionId)), TrainingPlan.class);
    }

    public TrainingPlan byId(String planId) {
        return mongo.findById(new ObjectId(planId), TrainingPlan.class);
    }

    public PlanView view(TrainingPlan plan) {
        if (plan == null) {
            return null;
        }
        var ids = (plan.sessions() == null ? Stream.<TrainingPlan.Session>empty() : plan.sessions().stream())
            .flatMap(s -> s.items() == null ? Stream.empty() : s.items().stream())
            .map(i -> i.exerciseId().toHexString())
            .collect(Collectors.toSet());
        Map<String, String> names = StreamSupport.stream(exercises.findAllById(ids).spliterator(), false)
            .filter(e -> Objects.nonNull(e.nameVi()))
            .collect(Collectors.toMap(Exercise::id, Exercise::nameVi));
        return PlanView.of(plan, names);
    }
}
