package vn.levelup.engagement.notification;

import java.util.Map;

import org.bson.types.ObjectId;

/**
 * Cổng gửi thông báo duy nhất (AGENTS.md). Job, coach, buddy đều gọi qua đây, không gọi FCM trực tiếp.
 * Phần cài đặt chịu trách nhiệm: pushEnabled, giờ yên lặng 22:00–07:00, tối đa maxPerDay (mặc định 2)
 * mỗi ngày theo giờ người dùng, chống gửi trùng bằng dedupeKey, xóa token FCM hết hạn.
 */
public interface NotificationGateway {

    /**
     * @param type      ví dụ "missed_session", "buddy_nudge", "weekly_review", "streak_risk"
     * @param dedupeKey khóa duy nhất, ví dụ "missed:userId:2026-10-05"; gửi lại cùng khóa thì bỏ qua
     * @param data      dữ liệu để app mở đúng màn (route, id...)
     */
    Result send(ObjectId userId, String type, String title, String body, String dedupeKey, Map<String, String> data);

    enum Result { SENT, STORED_ONLY, QUIET_HOURS, DAILY_LIMIT, DUPLICATE }
}
