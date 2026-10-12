package vn.levelup.training.controller;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;
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
import vn.levelup.training.service.ThisWeekPlanEnsurer;


@RestController
public class PlansController {

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final CurrentUserService currentUser;
    private final Clock clock;
    private final EmptySessionRepair repair;
    private final ThisWeekPlanEnsurer ensurer;

    public PlansController(MongoTemplate mongo, ExerciseRepository exercises,
                           CurrentUserService currentUser, Clock clock, EmptySessionRepair repair,
                           ThisWeekPlanEnsurer ensurer) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.currentUser = currentUser;
        this.clock = clock;
        this.repair = repair;
        this.ensurer = ensurer;
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

        // Tuần mới chưa chốt tổng kết: kích hoạt bản nháp hoặc lập từ lịch rảnh (không trả kế hoạch tuần trước)
        TrainingPlan plan = ensurer.ensure(user);
        if (plan == null) {
            // Chỉ kế hoạch từ tuần này trở đi (ví dụ onboarding Chủ nhật tối thì kế hoạch bắt đầu tuần sau)
            plan = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("status").is("active")
                .and("weekStart").gte(thisWeek)).with(Sort.by(Sort.Direction.ASC, "weekStart")), TrainingPlan.class);
        }
        if (plan == null) {
            // Không còn ngày rảnh nào trong tuần này: kế hoạch rỗng của tuần này, tập thêm vẫn tính chỉ tiêu
            int target = user.availability() == null ? 0 : user.availability().size();
            return new PlanView(null, thisWeek, "active", target, List.of());
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
