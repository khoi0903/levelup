package vn.levelup.demo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.util.List;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.test.context.ActiveProfiles;

import com.jayway.jsonpath.DocumentContext;
import vn.levelup.FlowTestBase;


/** POST /demo/{action} trên MongoDB dev (profile dev: bật demo cho uid "demo*"). */
@SpringBootTest
@ActiveProfiles("dev")
class DemoFlowTest extends FlowTestBase {

    @Override
    protected String uidPrefix() {
        return "demo-it-";
    }

    private DocumentContext demo(String action, int expected) throws Exception {
        return call(post("/demo/" + action).header("Authorization", token), expected);
    }

    @Test
    void non_demo_account_gets_404() throws Exception {
        call(post("/demo/seed").header("Authorization", "Bearer dev-it-not-demo"), 404);
        assertTrue(DemoController.allowed(List.of("demo*"), "demo-abc"));
        assertTrue(DemoController.allowed(List.of("x", "lan"), "lan"));
        assertTrue(!DemoController.allowed(List.of("demo*"), "it-demo"));
    }

    @Test
    void seed_is_idempotent_then_close_week() throws Exception {
        onboard();
        demo("seed", 200);
        DocumentContext seeded = demo("seed", 200);
        assertEquals(9, seeded.<Integer>read("$.result.workouts"));

        ObjectId userId = userId();
        Query mine = Query.query(Criteria.where("userId").is(userId));
        assertEquals(9, mongo.count(mine, "workout_logs"));
        assertEquals(5, mongo.count(mine, "weekly_streaks"));
        assertEquals(1, mongo.count(Query.query(Criteria.where("userId").is(userId)
            .and("newRecords.0").exists(true)), "workout_logs"));
        assertEquals(3, mongo.count(Query.query(Criteria.where("userId").is(userId)
            .and("status").is("achieved")), "weekly_streaks"));
        Document streak = user().get("streak", Document.class);
        assertEquals(3, ((Number) streak.get("currentWeeks")).intValue());
        // Cân nặng giảm dần 4 tuần và 21 bữa ăn 7 ngày trước; seed lại không nhân đôi
        assertEquals(4, seeded.<Integer>read("$.result.measurements"));
        assertEquals(4, mongo.count(mine, "body_measurements"));
        assertEquals(21, mongo.count(mine, "meal_logs"));
        assertEquals(5, ((Number) user().get("notificationSettings", Document.class).get("maxPerDay")).intValue());

        // Nút gửi thông báo đi qua cổng gửi thật (chưa có thiết bị thì chỉ lưu trong app)
        assertEquals("STORED_ONLY", demo("push-test", 200).read("$.result.result"));
        assertEquals("STORED_ONLY", demo("checkin", 200).read("$.result.result"));
        assertEquals(1, mongo.count(Query.query(Criteria.where("userId").is(userId).and("type").is("demo_test")),
            "notifications"));

        DocumentContext view = call(get("/streak").header("Authorization", token), 200);
        assertEquals(3, view.<Integer>read("$.currentWeeks"));

        demo("skip-two", 200);
        DocumentContext closed = demo("close-week", 200);
        assertTrue(closed.<Boolean>read("$.result.closed"));
        assertEquals("missed", closed.read("$.result.status"));
        assertEquals(0, closed.<Integer>read("$.result.currentWeeks"));
        assertEquals(false, demo("close-week", 200).<Boolean>read("$.result.closed"));
        demo("review", 200);
        demo("fly", 404);
    }
}
