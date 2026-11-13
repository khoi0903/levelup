package vn.levelup.training.service;

import java.time.Clock;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.identity.model.User;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.MuscleWeekView;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.repository.ExerciseRepository;
import vn.levelup.training.rules.MuscleRules;

/** Số hiệp theo nhóm cơ trong một tuần, tính từ workout_logs của chính người dùng. */
@Service
public class MuscleWeekService {

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final Clock clock;

    public MuscleWeekService(MongoTemplate mongo, ExerciseRepository exercises, Clock clock) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.clock = clock;
    }

    /** weekStart null: tuần hiện tại theo múi giờ người dùng. Ngày giữa tuần được đưa về Thứ Hai của tuần đó. */
    public MuscleWeekView week(User user, String weekStart) {
        LocalDate monday;
        try {
            monday = LocalDates.weekStart(weekStart == null || weekStart.isBlank()
                ? LocalDates.today(user.timezone(), clock) : LocalDate.parse(weekStart));
        } catch (DateTimeParseException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_DATE");
        }
        Query q = Query.query(Criteria.where("userId").is(new ObjectId(user.id()))
            .and("weekStart").is(monday.toString()));
        q.fields().include("sets.exerciseId");
        List<String> setExerciseIds = new ArrayList<>();
        for (Document log : mongo.find(q, Document.class, "workout_logs")) {
            for (Document set : log.getList("sets", Document.class, List.of())) {
                if (set.get("exerciseId") instanceof ObjectId id) {
                    setExerciseIds.add(id.toHexString());
                }
            }
        }
        Map<String, String> muscleById = new HashMap<>();
        for (Exercise e : exercises.findAllById(setExerciseIds.stream().distinct().toList())) {
            muscleById.put(e.id(), e.primaryMuscle());
        }
        List<String> muscles = setExerciseIds.stream().map(muscleById::get).toList();
        return new MuscleWeekView(monday.toString(), MuscleRules.countSets(muscles));
    }
}
