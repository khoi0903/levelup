package vn.levelup.training.service;

import java.time.Clock;
import java.time.LocalDate;
import java.util.Date;
import java.util.Optional;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;

import vn.levelup.identity.model.User;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.dto.ActivityDtos;

/** Lưu số bước và calo vận động hôm nay vào daily_stats.activity (một document mỗi người mỗi ngày). */
@Service
public class ActivityService {

    private final MongoTemplate mongo;
    private final Clock clock;

    public ActivityService(MongoTemplate mongo, Clock clock) {
        this.mongo = mongo;
        this.clock = clock;
    }

    public record Activity(int steps, int activeKcal) {}

    /**
     * App gửi số liệu cộng dồn từ 0h; dùng $max nên gửi lại hay gửi trễ (số nhỏ hơn) không làm giảm số đã lưu.
     */
    public ActivityDtos.ActivityView save(User user, ActivityDtos.ActivityRequest r) {
        ObjectId userId = new ObjectId(user.id());
        LocalDate today = LocalDates.today(user.timezone(), clock);
        if (!today.toString().equals(r.localDate())) {
            return new ActivityDtos.ActivityView(today.toString(), 0, 0, false);
        }
        mongo.upsert(day(userId, today), new Update()
            .max("activity.steps", r.steps())
            .max("activity.activeKcal", r.activeKcal())
            .set("activity.source", "health_connect")
            .set("activity.updatedAt", Date.from(clock.instant()))
            .setOnInsert("userId", userId).setOnInsert("localDate", today.toString()), "daily_stats");
        Activity a = today(userId, today).orElse(new Activity(r.steps(), r.activeKcal()));
        return new ActivityDtos.ActivityView(today.toString(), a.steps(), a.activeKcal(), true);
    }

    public Optional<Activity> today(ObjectId userId, LocalDate day) {
        return today(mongo, userId, day);
    }

    /** Dùng chung với CoachService (giống CheckinService.today). */
    public static Optional<Activity> today(MongoTemplate mongo, ObjectId userId, LocalDate day) {
        Document d = mongo.findOne(day(userId, day), Document.class, "daily_stats");
        if (d == null || !(d.get("activity") instanceof Document a)) {
            return Optional.empty();
        }
        return Optional.of(new Activity(num(a.get("steps")), num(a.get("activeKcal"))));
    }

    private static Query day(ObjectId userId, LocalDate day) {
        return Query.query(Criteria.where("userId").is(userId).and("localDate").is(day.toString()));
    }

    private static int num(Object o) {
        return o instanceof Number n ? n.intValue() : 0;
    }
}
