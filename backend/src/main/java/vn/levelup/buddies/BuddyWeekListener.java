package vn.levelup.buddies;

import java.util.Date;
import java.util.List;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Component;

import vn.levelup.motivation.WeekClosedListener;

/**
 * F4 + F5: sau khi chốt tuần, cả hai buddy đều "achieved" thì sharedStreakWeeks + 1, một người không đạt
 * thì về 0. Chỉ tính khi tuần của CẢ HAI đã chốt (listener chạy cho từng người, người chốt sau mới tính).
 * Chạy lại an toàn nhờ lastSharedWeek. Đủ 4 tuần liền thì cả hai nhận huy hiệu buddy_goal_weeks_4.
 */
@Component
public class BuddyWeekListener implements WeekClosedListener {

    static final String GOAL_ACHIEVEMENT = "buddy_goal_weeks_4";
    static final int GOAL_WEEKS = 4;

    private final MongoTemplate mongo;

    public BuddyWeekListener(MongoTemplate mongo) {
        this.mongo = mongo;
    }

    @Override
    public void onWeekClosed(ObjectId userId, String weekStart) {
        Document pair = mongo.findOne(Query.query(Criteria.where("members").is(userId).and("status").is("active")),
            Document.class, "buddy_pairs");
        if (pair == null || weekStart.equals(pair.getString("lastSharedWeek"))) {
            return;
        }
        List<ObjectId> members = pair.getList("members", ObjectId.class, List.of());
        if (members.size() != 2) {
            return;
        }
        Document a = week(members.get(0), weekStart);
        Document b = week(members.get(1), weekStart);
        if (a == null || b == null || a.get("closedAt") == null || b.get("closedAt") == null) {
            return;                                    // chờ người còn lại chốt tuần
        }
        boolean both = "achieved".equals(a.getString("status")) && "achieved".equals(b.getString("status"));
        int before = pair.get("sharedStreakWeeks") instanceof Number n ? n.intValue() : 0;
        int after = both ? before + 1 : 0;

        // Điều kiện lastSharedWeek khác tuần này: hai lần chốt song song chỉ một lần được tính
        Query sameWeekNotCounted = Query.query(Criteria.where("_id").is(pair.getObjectId("_id"))
            .and("lastSharedWeek").ne(weekStart));
        var result = mongo.updateFirst(sameWeekNotCounted,
            new Update().set("sharedStreakWeeks", after).set("lastSharedWeek", weekStart), "buddy_pairs");
        if (result.getModifiedCount() == 0 || after < GOAL_WEEKS || before >= GOAL_WEEKS) {
            return;
        }
        Document achievement = new Document("code", GOAL_ACHIEVEMENT).append("earnedAt", new Date())
            .append("context", new Document("pairId", pair.getObjectId("_id")).append("weekStart", weekStart));
        for (ObjectId member : members) {
            mongo.updateFirst(Query.query(Criteria.where("_id").is(member).and("achievements.code").ne(GOAL_ACHIEVEMENT)),
                new Update().push("achievements", achievement), "users");
        }
    }

    private Document week(ObjectId userId, String weekStart) {
        return mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(weekStart)),
            Document.class, "weekly_streaks");
    }
}
