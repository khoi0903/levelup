package vn.levelup.engagement.notification;

import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Bộ gửi khi chưa có service account (dev, test): chỉ ghi log. Bản thật là FcmPushSender (xem PushConfig).
 * Token bắt đầu bằng "expired-" được coi là hết hạn, để thử luồng xóa token khi phát triển.
 */
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
