package vn.levelup.notifications;

import java.util.Map;

import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/** Tạm thời: chỉ ghi log. Sẽ được thay bằng cổng gửi thật (giới hạn, giờ yên lặng, FCM). */
@Service
public class LogOnlyNotificationGateway implements NotificationGateway {

    private static final Logger log = LoggerFactory.getLogger(LogOnlyNotificationGateway.class);

    @Override
    public Result send(ObjectId userId, String type, String title, String body, String dedupeKey,
                       Map<String, String> data) {
        log.info("[notify] user={} type={} key={} title={}", userId, type, dedupeKey, title);
        return Result.STORED_ONLY;
    }
}
