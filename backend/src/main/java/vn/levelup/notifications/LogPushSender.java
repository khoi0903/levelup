package vn.levelup.notifications;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Tạm thời: chỉ ghi log thay cho FCM (TODO: gửi qua Firebase Admin SDK).
 * Token bắt đầu bằng "expired-" được coi là hết hạn, để thử luồng xóa token khi phát triển.
 */
@Component
public class LogPushSender implements PushSender {

    private static final Logger log = LoggerFactory.getLogger(LogPushSender.class);

    @Override
    public Outcome send(String token, String platform, String title, String body, Map<String, String> data) {
        if (token.startsWith("expired-")) {
            log.info("[push] token hết hạn platform={}", platform);
            return Outcome.TOKEN_EXPIRED;
        }
        log.info("[push] platform={} title={}", platform, title);
        return Outcome.SENT;
    }
}
