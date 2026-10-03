package vn.levelup.notifications;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import java.util.List;
import java.util.Map;

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
import vn.levelup.notifications.NotificationGateway.Result;

/** Cổng gửi thông báo và POST /devices trên MongoDB dev. */
@SpringBootTest
@ActiveProfiles("dev")
class NotificationFlowTest extends FlowTestBase {

    @Autowired NotificationGateway gateway;

    private void device(String token, String platform, int expected) throws Exception {
        call(post("/devices").header("Authorization", this.token).contentType(MediaType.APPLICATION_JSON)
            .content("{\"token\":\"%s\",\"platform\":\"%s\"}".formatted(token, platform)), expected);
    }

    /** Tắt giờ yên lặng để test không phụ thuộc giờ chạy. */
    private void noQuietHours(ObjectId userId, boolean pushEnabled) {
        mongo.updateFirst(Query.query(Criteria.where("_id").is(userId)), new Update()
            .set("notificationSettings", new Document("pushEnabled", pushEnabled)
                .append("quietStart", "00:00").append("quietEnd", "00:00")), "users");
    }

    @Test
    void devices_are_unique_by_token() throws Exception {
        onboard();
        device("tok-1", "android", 204);
        device("tok-1", "android", 204);
        device("tok-2", "web", 204);
        device("tok-3", "symbian", 400);
        List<Document> devices = user().getList("devices", Document.class);
        assertEquals(2, devices.size());
        assertEquals(List.of("tok-1", "tok-2"), devices.stream().map(d -> d.getString("token")).toList());
    }

    @Test
    void daily_limit_and_dedupe() throws Exception {
        onboard();
        ObjectId userId = userId();
        String prefix = userId.toHexString() + "|test|";

        // Chưa có thiết bị: chỉ lưu trong app, không tốn lượt
        noQuietHours(userId, true);
        assertEquals(Result.STORED_ONLY, gateway.send(userId, "missed_2", "T", "B", prefix + "0", Map.of()));

        device("tok-" + userId.toHexString(), "android", 204);
        assertEquals(Result.SENT, gateway.send(userId, "missed_2", "T", "B", prefix + "1", Map.of("route", "/")));
        assertEquals(Result.DUPLICATE, gateway.send(userId, "missed_2", "T", "B", prefix + "1", Map.of()));
        assertEquals(Result.SENT, gateway.send(userId, "lapsed", "T", "B", prefix + "2", Map.of()));
        assertEquals(Result.DAILY_LIMIT, gateway.send(userId, "lapsed", "T", "B", prefix + "3", Map.of()));
        // Đã gửi rồi thì vẫn là DUPLICATE dù hết lượt
        assertEquals(Result.DUPLICATE, gateway.send(userId, "lapsed", "T", "B", prefix + "2", Map.of()));

        Query mine = Query.query(Criteria.where("userId").is(userId));
        assertEquals(3, mongo.count(mine, "notifications"));
        assertEquals(2, mongo.count(Query.query(Criteria.where("userId").is(userId).and("sentAt").exists(true)),
            "notifications"));
        Document stats = mongo.findOne(mine, Document.class, "daily_stats");
        assertEquals(2, ((Number) stats.get("notificationsSent")).intValue());
    }

    @Test
    void push_disabled_stores_only_and_expired_token_is_removed() throws Exception {
        onboard();
        ObjectId userId = userId();
        device("expired-" + userId.toHexString(), "ios", 204);

        noQuietHours(userId, false);
        assertEquals(Result.STORED_ONLY, gateway.send(userId, "lapsed", "T", "B", null, Map.of()));
        assertEquals(1, user().getList("devices", Document.class).size());

        noQuietHours(userId, true);
        assertEquals(Result.STORED_ONLY, gateway.send(userId, "lapsed", "T", "B", null, Map.of()));
        assertEquals(0, user().getList("devices", Document.class).size());
        Document stats = mongo.findOne(Query.query(Criteria.where("userId").is(userId)), Document.class, "daily_stats");
        assertEquals(0, ((Number) stats.get("notificationsSent")).intValue());
    }
}
