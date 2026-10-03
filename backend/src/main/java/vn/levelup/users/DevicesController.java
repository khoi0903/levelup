package vn.levelup.users;

import java.time.Clock;
import java.util.Date;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import vn.levelup.auth.CurrentUserService;

@RestController
public class DevicesController {

    /** Giữ tối đa chừng này thiết bị gần nhất cho mỗi người dùng. */
    static final int MAX_DEVICES = 10;

    private final MongoTemplate mongo;
    private final CurrentUserService currentUser;
    private final Clock clock;

    public DevicesController(MongoTemplate mongo, CurrentUserService currentUser, Clock clock) {
        this.mongo = mongo;
        this.currentUser = currentUser;
        this.clock = clock;
    }

    public record DeviceRequest(
        @NotBlank @Size(max = 4096) String token,
        @NotNull @Pattern(regexp = "android|ios|web") String platform
    ) {}

    /**
     * Lưu FCM token sau khi người dùng bật thông báo (F1). Gửi lại cùng token thì chỉ cập nhật lastSeenAt.
     * Token đang gắn với tài khoản khác trên cùng máy thì gỡ khỏi tài khoản đó.
     */
    @PostMapping("/devices")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void register(@Valid @RequestBody DeviceRequest request) {
        ObjectId userId = new ObjectId(currentUser.require().id());
        Date now = Date.from(clock.instant());

        mongo.updateMulti(Query.query(Criteria.where("_id").ne(userId).and("devices.token").is(request.token())),
            new Update().pull("devices", new Document("token", request.token())), "users");

        var known = mongo.updateFirst(
            Query.query(Criteria.where("_id").is(userId).and("devices.token").is(request.token())),
            new Update().set("devices.$.lastSeenAt", now).set("devices.$.platform", request.platform()), "users");
        if (known.getMatchedCount() == 0) {
            // Điều kiện "chưa có token" để hai request song song không thêm trùng
            mongo.updateFirst(
                Query.query(Criteria.where("_id").is(userId).and("devices.token").ne(request.token())),
                new Update().push("devices").slice(-MAX_DEVICES).each(new Document("token", request.token())
                    .append("platform", request.platform()).append("lastSeenAt", now)), "users");
        }
    }
}
