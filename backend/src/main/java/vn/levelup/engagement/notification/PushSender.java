package vn.levelup.engagement.notification;

import java.util.Map;

/**
 * Gửi push tới một thiết bị. Chỉ {@link MongoNotificationGateway} gọi interface này;
 * nơi khác luôn đi qua {@link NotificationGateway}.
 */
public interface PushSender {

    Outcome send(String token, String platform, String title, String body, Map<String, String> data);

    /** TOKEN_EXPIRED: cổng gửi xóa token khỏi users.devices, app gửi token mới khi mở lại. */
    enum Outcome { SENT, TOKEN_EXPIRED, FAILED }
}
