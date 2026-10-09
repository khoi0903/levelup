package vn.levelup.training.service;

import java.time.Clock;
import java.util.Date;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.StreamSupport;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.identity.model.User;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.TodayCheckin;
import vn.levelup.training.dto.CheckinRequest;
import vn.levelup.training.dto.PlanView;
import vn.levelup.training.model.Exercise;
import vn.levelup.training.model.TrainingPlan;
import vn.levelup.training.repository.ExerciseRepository;
import vn.levelup.training.rules.CheckinAdjuster;


@Service
public class CheckinService {

    private final MongoTemplate mongo;
    private final ExerciseRepository exercises;
    private final Clock clock;

    public CheckinService(MongoTemplate mongo, ExerciseRepository exercises, Clock clock) {
        this.mongo = mongo;
        this.exercises = exercises;
        this.clock = clock;
    }

    /** Check-in của ngày này (theo localDate người dùng), chưa check-in thì null. Dùng cho /me và coach. */
    public static TodayCheckin today(MongoTemplate mongo, ObjectId userId, String localDate) {
        Document day = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("localDate").is(localDate)
            .and("checkin").exists(true)), Document.class, "daily_stats");
        if (day == null || !(day.get("checkin") instanceof Document c)) {
            return null;
        }
        return new TodayCheckin(c.getString("energy"), c.getString("sleep"));
    }

    public TodayCheckin today(ObjectId userId, String localDate) {
        return today(mongo, userId, localDate);
    }

    /** Check-in và điều chỉnh buổi tập cùng transaction, không ghi đè dữ liệu của ngày hay plan. */
    @Transactional
    public CheckinResponse complete(User user, CheckinRequest request) {
        ObjectId userId = new ObjectId(user.id());
        String localDate = LocalDates.today(user.timezone(), clock).toString();

        Query checkedIn = Query.query(Criteria.where("userId").is(userId)
            .and("localDate").is(localDate).and("checkin").exists(true));
        if (mongo.exists(checkedIn, "daily_stats")) {
            throw alreadyCheckedIn();
        }

        Document checkin = new Document("energy", request.energy())
            .append("at", Date.from(clock.instant()));
        if (request.sleep() != null) {
            checkin.append("sleep", request.sleep());
        }
        // Điều kiện chưa có checkin + unique index (userId, localDate) ngăn ghi đè check-in cũ.
        Query notCheckedIn = Query.query(Criteria.where("userId").is(userId)
            .and("localDate").is(localDate).and("checkin").exists(false));
        try {
            mongo.upsert(notCheckedIn, new Update().set("checkin", checkin)
                .setOnInsert("userId", userId).setOnInsert("localDate", localDate), "daily_stats");
        } catch (DuplicateKeyException e) {
            throw alreadyCheckedIn();
        }

        Criteria todayPlanned = Criteria.where("scheduledDate").is(localDate).and("status").is("planned");
        TrainingPlan plan = mongo.findOne(Query.query(Criteria.where("userId").is(userId)
            .and("status").is("active").and("sessions").elemMatch(todayPlanned)), TrainingPlan.class);
        if (plan == null) {
            return new CheckinResponse(localDate, request.energy(), request.sleep(), false, null);
        }

        TrainingPlan.Session today = plan.sessions().stream()
            .filter(s -> localDate.equals(s.scheduledDate()) && "planned".equals(s.status()))
            .findFirst().orElseThrow();
        CheckinAdjuster.Adjustment adjustment = CheckinAdjuster.adjust(today, request.energy(), request.sleep());
        TrainingPlan.Session session = adjustment.session();
        if (adjustment.adjusted()) {
            Query selectedSession = Query.query(Criteria.where("_id").is(new ObjectId(plan.id()))
                .and("userId").is(userId).and("status").is("active")
                .and("sessions").elemMatch(Criteria.where("_id").is(today.id())
                    .and("scheduledDate").is(localDate).and("status").is("planned")));
            Update update = new Update().set("sessions.$.variant", session.variant())
                .set("sessions.$.adjustedReason", session.adjustedReason());
            if ("checkin_tired".equals(session.adjustedReason()) && session.items() != null) {
                for (int i = 0; i < session.items().size(); i++) {
                    Integer sets = session.items().get(i).targetSets();
                    if (sets != null) {
                        update.set("sessions.$.items." + i + ".targetSets", sets);
                    }
                }
            }
            mongo.updateFirst(selectedSession, update, TrainingPlan.class);
        }

        var ids = session.items() == null ? java.util.Set.<String>of() : session.items().stream()
            .map(i -> i.exerciseId().toHexString()).collect(Collectors.toSet());
        Map<String, String> names = StreamSupport.stream(exercises.findAllById(ids).spliterator(), false)
            .collect(Collectors.toMap(Exercise::id, Exercise::nameVi));
        List<PlanView.ItemView> items = session.items() == null ? List.of() : session.items().stream()
            .map(i -> new PlanView.ItemView(i.exerciseId().toHexString(), names.get(i.exerciseId().toHexString()),
                i.targetSets(), i.targetReps(), i.targetDurationSec(), i.restSec()))
            .toList();
        PlanView.SessionView view = new PlanView.SessionView(session.id().toHexString(), session.scheduledDate(),
            session.scheduledTime(), session.title(), session.durationMin(), session.variant(), session.status(),
            items, session.adjustedReason());
        return new CheckinResponse(localDate, request.energy(), request.sleep(), adjustment.adjusted(), view);
    }

    private static ResponseStatusException alreadyCheckedIn() {
        return new ResponseStatusException(HttpStatus.CONFLICT, "ALREADY_CHECKED_IN");
    }

    public record CheckinResponse(String localDate, String energy, String sleep,
                                  boolean adjusted, PlanView.SessionView session) {}
}
