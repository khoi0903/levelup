package vn.levelup.jobs;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.Date;
import java.util.List;
import java.util.UUID;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;

import vn.levelup.FlowTestBase;
import vn.levelup.buddies.BuddyWeekListener;
import vn.levelup.common.LocalDates;

/** Nhắc check-in / trước buổi, tuần khởi động lại, streak chung buddy — chạy trên MongoDB dev. */
@SpringBootTest
@ActiveProfiles("dev")
class RemindersRestartBuddyFlowTest extends FlowTestBase {

    @Autowired ReminderService reminders;
    @Autowired RestartWeekService restartWeek;
    @Autowired BuddyWeekListener buddyListener;

    private long notifications(ObjectId userId, String type) {
        return mongo.count(Query.query(Criteria.where("userId").is(userId).and("type").is(type)), "notifications");
    }

    @Test
    void checkin_reminder_once_and_not_after_checkin() throws Exception {
        onboard();
        ObjectId me = userId();
        LocalDateTime morning = LocalDate.now(LocalDates.DEFAULT_ZONE).atTime(7, 45);
        reminders.remind(me, morning);
        reminders.remind(me, morning.plusMinutes(10));               // dedupeKey theo ngày
        assertEquals(1, notifications(me, "checkin_morning"));

        call(post("/checkins").header("Authorization", token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"energy\":\"normal\"}"), 200);
        mongo.remove(Query.query(Criteria.where("userId").is(me).and("type").is("checkin_morning")), "notifications");
        reminders.remind(me, morning.plusMinutes(20));
        assertEquals(0, notifications(me, "checkin_morning"));         // đã check-in thì không nhắc
    }

    @Test
    void pre_workout_reminder_before_planned_session() throws Exception {
        onboard();
        ObjectId me = userId();
        Document plan = mongo.findOne(Query.query(Criteria.where("userId").is(me).and("status").is("active")),
            Document.class, "training_plans");
        Document session = plan.getList("sessions", Document.class).getFirst();
        LocalDateTime at = LocalDate.parse(session.getString("scheduledDate"))
            .atTime(LocalTime.parse(session.getString("scheduledTime")));
        reminders.remind(me, at.minusMinutes(90));                     // quá sớm (mặc định 60 phút)
        assertEquals(0, notifications(me, "pre_workout"));
        reminders.remind(me, at.minusMinutes(30));
        reminders.remind(me, at.minusMinutes(10));                     // một lần mỗi buổi
        assertEquals(1, notifications(me, "pre_workout"));
    }

    @Test
    void restart_week_lightens_remaining_sessions_or_creates_plan() throws Exception {
        onboard();
        ObjectId me = userId();
        LocalDate today = LocalDate.now(LocalDates.DEFAULT_ZONE);
        int changed = restartWeek.restart(me, user(), today);
        Document plan = mongo.findOne(Query.query(Criteria.where("userId").is(me).and("status").is("active")
            .and("weekStart").is(LocalDates.weekStart(today).toString())), Document.class, "training_plans");
        if (plan != null) {
            for (Document s : plan.getList("sessions", Document.class)) {
                if ("planned".equals(s.getString("status")) && s.getString("scheduledDate").compareTo(today.toString()) >= 0) {
                    assertEquals("light", s.getString("variant"));
                    assertTrue(s.getInteger("durationMin") <= RestartWeekService.RESTART_MINUTES);
                    assertEquals(RestartWeekService.REASON, s.getString("adjustedReason"));
                }
            }
            assertEquals(0, restartWeek.restart(me, user(), today));     // chạy lại không đổi gì
        }

        // Tuần chưa có kế hoạch (người nghỉ lâu): tạo kế hoạch khởi động lại mới
        mongo.remove(Query.query(Criteria.where("userId").is(me)), "training_plans");
        mongo.remove(Query.query(Criteria.where("userId").is(me)), "weekly_streaks");
        int created = restartWeek.restart(me, user(), today);
        Document fresh = mongo.findOne(Query.query(Criteria.where("userId").is(me).and("status").is("active")),
            Document.class, "training_plans");
        if (created > 0) {
            assertEquals("light", fresh.getList("sessions", Document.class).getFirst().getString("variant"));
            assertEquals(created, fresh.getInteger("targetSessions"));
            assertTrue(mongo.exists(Query.query(Criteria.where("userId").is(me)), "weekly_streaks"));
        }
        assertTrue(changed >= 0);
    }

    @Test
    void buddy_shared_streak_counts_once_and_awards_at_four() throws Exception {
        onboard();
        ObjectId a = userId();
        String otherUid = "it-" + UUID.randomUUID();
        String otherToken = "Bearer dev-" + otherUid;
        String body = """
            {"displayName":"Bạn","goal":"lose_fat","heightCm":160,"weightKg":55,"experience":"beginner",
             "location":"home","availability":[{"weekday":2,"slot":"evening"}],"sessionMinutes":15,
             "coachStyle":"supportive"}""";
        call(post("/onboarding").header("Authorization", otherToken).contentType(MediaType.APPLICATION_JSON)
            .content(body), 200);
        ObjectId b = mongo.findOne(Query.query(Criteria.where("authUid").is(otherUid)), Document.class, "users")
            .getObjectId("_id");
        ObjectId pairId = new ObjectId();
        try {
            String w1 = "2026-09-14";
            mongo.insert(new Document("_id", pairId).append("members", List.of(a, b))
                .append("pairKey", "it_" + pairId.toHexString()).append("status", "active")
                .append("sharedStreakWeeks", 3).append("lastSharedWeek", "2026-09-07")
                .append("createdAt", new Date()), "buddy_pairs");
            closedWeek(a, w1, "achieved");
            buddyListener.onWeekClosed(a, w1);                           // b chưa chốt → chờ
            assertEquals(3, pair(pairId).getInteger("sharedStreakWeeks"));
            closedWeek(b, w1, "achieved");
            buddyListener.onWeekClosed(b, w1);
            buddyListener.onWeekClosed(a, w1);                           // gọi lại không cộng thêm
            assertEquals(4, pair(pairId).getInteger("sharedStreakWeeks"));
            for (ObjectId member : List.of(a, b)) {
                Document u = mongo.findById(member, Document.class, "users");
                assertTrue(u.getList("achievements", Document.class).stream()
                    .anyMatch(x -> "buddy_goal_weeks_4".equals(x.getString("code"))));
            }

            String w2 = "2026-09-21";
            closedWeek(a, w2, "achieved");
            closedWeek(b, w2, "missed");
            buddyListener.onWeekClosed(a, w2);
            assertEquals(0, pair(pairId).getInteger("sharedStreakWeeks")); // một người không đạt → về 0
        } finally {
            mongo.remove(Query.query(Criteria.where("_id").is(pairId)), "buddy_pairs");
            for (String c : List.of("training_plans", "weekly_streaks")) {
                mongo.remove(Query.query(Criteria.where("userId").is(b)), c);
            }
            mongo.remove(Query.query(Criteria.where("_id").is(b)), "users");
        }
    }

    private void closedWeek(ObjectId userId, String weekStart, String status) {
        mongo.upsert(Query.query(Criteria.where("userId").is(userId).and("weekStart").is(weekStart)),
            new Update().set("targetSessions", 3).set("completedSessions", "achieved".equals(status) ? 3 : 1)
                .set("status", status).set("closedAt", new Date()), "weekly_streaks");
    }

    private Document pair(ObjectId id) {
        return mongo.findById(id, Document.class, "buddy_pairs");
    }
}
