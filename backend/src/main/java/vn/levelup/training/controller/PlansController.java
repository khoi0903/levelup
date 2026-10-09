package vn.levelup.training.controller;

import java.time.Clock;
import java.time.LocalDate;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.StreamSupport;

import org.bson.types.ObjectId;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.identity.model.User;
import vn.levelup.identity.service.CurrentUserService;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.PlanView;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.repository.ExerciseRepository;
import vn.levelup.training.service.EmptySessionRepair;


@RestController
public class PlansController {

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final CurrentUserService currentUser;
    private final Clock clock;
    private final EmptySessionRepair repair;

    public PlansController(MongoTemplate mongo, ExerciseRepository exercises,
                           CurrentUserService currentUser, Clock clock, EmptySessionRepair repair) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.currentUser = currentUser;
        this.clock = clock;
        this.repair = repair;
    }

    /**
     * Kế hoạch đang áp dụng: tuần này, nếu chưa có thì kế hoạch active gần nhất
     * (ví dụ onboarding vào Chủ nhật tối thì kế hoạch bắt đầu từ tuần sau).
     */
    @GetMapping("/plans/current")
    public PlanView current() {
        User user = currentUser.require();
        ObjectId userId = new ObjectId(user.id());
        LocalDate today = LocalDates.today(user.timezone(), clock);
        String thisWeek = LocalDates.weekStart(today).toString();

        Criteria active = Criteria.where("userId").is(userId).and("status").is("active");
        TrainingPlan plan = mongo.findOne(
            Query.query(new Criteria().andOperator(active, Criteria.where("weekStart").is(thisWeek))),
            TrainingPlan.class);
        if (plan == null) {
            plan = mongo.findOne(Query.query(active).with(Sort.by(Sort.Direction.DESC, "weekStart")),
                TrainingPlan.class);
        }
        if (plan == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "NO_ACTIVE_PLAN");
        }
        plan = repair.repair(user, plan);

        var ids = plan.sessions().stream()
            .flatMap(s -> s.items() == null ? java.util.stream.Stream.empty() : s.items().stream())
            .map(i -> i.exerciseId().toHexString())
            .collect(Collectors.toSet());
        Map<String, String> names = StreamSupport.stream(exercises.findAllById(ids).spliterator(), false)
            .collect(Collectors.toMap(Exercise::id, Exercise::nameVi));
        return PlanView.of(plan, names);
    }
}
