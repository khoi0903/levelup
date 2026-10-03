package vn.levelup.motivation;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import vn.levelup.auth.CurrentUserService;
import vn.levelup.common.LocalDates;
import vn.levelup.users.User;

@RestController
public class StreakController {

    static final int HISTORY_WEEKS = 8;
    /** Đủ để đếm streak dài; streak hơn một năm thì job chốt tuần giữ trong users.streak.bestWeeks. */
    private static final int LOOKBACK_WEEKS = 60;

    private final MongoTemplate mongo;
    private final CurrentUserService currentUser;
    private final Clock clock;

    public StreakController(MongoTemplate mongo, CurrentUserService currentUser, Clock clock) {
        this.mongo = mongo;
        this.currentUser = currentUser;
        this.clock = clock;
    }

    /** F4: streak hiện tại, kỷ lục, thẻ đóng băng, 8 tuần gần nhất (cũ trước mới sau). */
    @GetMapping("/streak")
    public StreakView streak() {
        User user = currentUser.require();
        ObjectId userId = new ObjectId(user.id());
        LocalDate thisWeek = LocalDates.weekStart(LocalDates.today(user.timezone(), clock));

        List<StreakCalculator.Week> weeks = mongo.find(Query.query(Criteria.where("userId").is(userId)
                    .and("weekStart").gte(thisWeek.minusWeeks(LOOKBACK_WEEKS).toString()))
                .with(Sort.by(Sort.Direction.DESC, "weekStart")), Document.class, "weekly_streaks")
            .stream()
            .map(d -> new StreakCalculator.Week(d.getString("weekStart"), number(d, "targetSessions"),
                number(d, "completedSessions"), d.getString("status")))
            .toList();

        int current = StreakCalculator.currentWeeks(weeks, thisWeek);
        User.Streak stored = user.streak();
        int best = Math.max(current, stored == null || stored.bestWeeks() == null ? 0 : stored.bestWeeks());
        int freezes = stored == null || stored.freezesAvailable() == null ? 0 : stored.freezesAvailable();
        List<StreakCalculator.Week> history = StreakCalculator.lastWeeks(weeks, thisWeek, HISTORY_WEEKS);
        return new StreakView(current, best, freezes, history.getLast(), history);
    }

    private static int number(Document d, String key) {
        Object v = d.get(key);
        return v instanceof Number n ? n.intValue() : 0;
    }

    public record StreakView(int currentWeeks, int bestWeeks, int freezesAvailable,
                             StreakCalculator.Week thisWeek, List<StreakCalculator.Week> weeks) {}
}
