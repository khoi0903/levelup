package vn.levelup.jobs;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.time.Clock;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.test.context.ActiveProfiles;

import com.jayway.jsonpath.DocumentContext;

import vn.levelup.FlowTestBase;
import vn.levelup.common.LocalDates;
import vn.levelup.motivation.WeekClosedListener;

/** Chốt ngày, chốt tuần gọi trực tiếp service (không gọi /jobs/tick vì tick duyệt mọi người dùng trong DB dev). */
@SpringBootTest
@ActiveProfiles("dev")
class JobsFlowTest extends FlowTestBase {

    static final List<String> CLOSED = new ArrayList<>();

    @TestConfiguration
    static class Listeners {
        @Bean
        WeekClosedListener recordingListener() {
            return (userId, weekStart) -> CLOSED.add(userId.toHexString() + "|" + weekStart);
        }

        @Bean
        WeekClosedListener failingListener() {
            return (userId, weekStart) -> {
                throw new IllegalStateException("listener lỗi không được làm hỏng chốt tuần");
            };
        }
    }

    @Autowired DailyCloseService dailyClose;
    @Autowired WeekCloseService weekClose;
    @Autowired Clock clock;

    private Query mine(ObjectId userId) {
        return Query.query(Criteria.where("userId").is(userId));
    }

    @Test
    void week_close_achieved_adds_streak_and_creates_next_week_once() throws Exception {
        onboard();
        ObjectId userId = userId();
        LocalDate thisWeek = LocalDates.weekStart(LocalDates.today("Asia/Ho_Chi_Minh", clock));
        Query week = Query.query(Criteria.where("userId").is(userId).and("weekStart").is(thisWeek.toString()));
        Document doc = mongo.findOne(week, Document.class, "weekly_streaks");
        int target = ((Number) doc.get("targetSessions")).intValue();
        mongo.updateFirst(week, Update.update("completedSessions", target).set("status", "achieved"),
            "weekly_streaks");

        WeekCloseService.WeekResult first = weekClose.closeWeek(userId, thisWeek);
        assertTrue(first.closed());
        assertEquals("achieved", first.status());
        assertEquals(1, first.currentWeeks());
        assertTrue(CLOSED.contains(userId.toHexString() + "|" + thisWeek));

        Document closed = mongo.findOne(week, Document.class, "weekly_streaks");
        assertNotNull(closed.get("closedAt"));
        Document next = mongo.findOne(Query.query(Criteria.where("userId").is(userId)
            .and("weekStart").is(thisWeek.plusWeeks(1).toString())), Document.class, "weekly_streaks");
        assertEquals("in_progress", next.getString("status"));
        assertEquals(target, ((Number) next.get("targetSessions")).intValue());
        assertEquals(0, ((Number) next.get("completedSessions")).intValue());

        // Chạy lại: không cộng streak lần nữa, không gọi listener lần nữa
        int calls = CLOSED.size();
        assertFalse(weekClose.closeWeek(userId, thisWeek).closed());
        Document streak = user().get("streak", Document.class);
        assertEquals(1, ((Number) streak.get("currentWeeks")).intValue());
        assertEquals(thisWeek.toString(), streak.getString("lastClosedWeek"));
        assertEquals(calls, CLOSED.size());
    }

    @Test
    void second_missed_session_asks_reason_once() throws Exception {
        DocumentContext onboarding = onboard();
        ObjectId userId = userId();
        ObjectId sessionId = new ObjectId(onboarding.<String>read("$.plan.sessions[0].id"));
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)), new Update()
            .set("reengagement", new Document("stage", "missed_1").append("consecutiveMissed", 1)
                .append("lastWorkoutAt", new java.util.Date())), "users");

        DailyCloseService.DayResult r = dailyClose.skipSessions(userId, List.of(sessionId));
        assertEquals(1, r.skipped());
        assertEquals("missed_2", r.stageAfter());
        assertEquals(List.of("missed_2"), r.notified());

        Document message = mongo.findOne(mine(userId), Document.class, "coach_messages");
        assertEquals("coach", message.getString("role"));
        assertEquals("missed_2", message.getString("trigger"));
        assertEquals(5, message.get("card", Document.class).getList("options", Document.class).size());
        Document notification = mongo.findOne(mine(userId), Document.class, "notifications");
        assertEquals("missed_2", notification.getString("type"));
        assertTrue(notification.getString("dedupeKey").endsWith("|missed_2"));

        // Chốt lại cùng ngày: không còn buổi planned, không tạo tin mới
        DailyCloseService.DayResult again = dailyClose.closeDay(userId, LocalDate.parse(
            onboarding.read("$.plan.sessions[0].scheduledDate")));
        assertEquals(0, again.skipped());
        assertEquals(1, mongo.count(mine(userId), "coach_messages"));
        Document re = user().get("reengagement", Document.class);
        assertEquals(2, ((Number) re.get("consecutiveMissed")).intValue());
    }

    @Test
    void tick_requires_job_secret() throws Exception {
        call(post("/jobs/tick").header("Authorization", token), 403);
        DocumentContext wrong = call(post("/jobs/tick").header("Authorization", token)
            .header("X-Job-Secret", "nope"), 403);
        assertEquals("FORBIDDEN", wrong.read("$.code"));
    }
}
