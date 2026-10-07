package vn.levelup.engagement.rules;

import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.format.DateTimeParseException;

/** Luật của cổng gửi thông báo, không đọc hay ghi database, để unit test. */
public final class NotificationRules {

    public static final LocalTime DEFAULT_QUIET_START = LocalTime.of(22, 0);
    public static final LocalTime DEFAULT_QUIET_END = LocalTime.of(7, 0);
    public static final int DEFAULT_MAX_PER_DAY = 2;

    /** Nhắc uống nước: người dùng tự bật, có lượt riêng, không chiếm lượt của nhắc tập. */
    public static final String WATER_TYPE = "water_reminder";
    public static final int WATER_MAX_PER_DAY = 2;

    private NotificationRules() {}

    /** "HH:mm" của notificationSettings; thiếu hoặc sai thì dùng giá trị mặc định. */
    public static LocalTime time(String value, LocalTime fallback) {
        if (value == null || value.isBlank()) {
            return fallback;
        }
        try {
            return LocalTime.parse(value.trim());
        } catch (DateTimeParseException e) {
            return fallback;
        }
    }

    /** Bộ đếm trong daily_stats cho loại thông báo này. */
    public static String counterField(String type) {
        return WATER_TYPE.equals(type) ? "waterRemindersSent" : "notificationsSent";
    }

    /** Giới hạn mỗi ngày cho loại thông báo này. */
    public static int limitFor(String type, Object maxPerDaySetting) {
        return WATER_TYPE.equals(type) ? WATER_MAX_PER_DAY : maxPerDay(maxPerDaySetting);
    }

    public static int maxPerDay(Object value) {
        return value instanceof Number n ? Math.max(0, n.intValue()) : DEFAULT_MAX_PER_DAY;
    }

    /**
     * Có đang trong giờ yên lặng không. Khoảng có thể vắt qua nửa đêm (22:00–07:00).
     * start == end nghĩa là người dùng tắt giờ yên lặng.
     */
    public static boolean isQuiet(LocalTime now, LocalTime start, LocalTime end) {
        if (start.equals(end)) {
            return false;
        }
        if (start.isBefore(end)) {
            return !now.isBefore(start) && now.isBefore(end);
        }
        return !now.isBefore(start) || now.isBefore(end);
    }

    /** Lần quietEnd kế tiếp sau thời điểm này, để hẹn gửi lại. */
    public static Instant nextQuietEnd(Instant now, ZoneId zone, LocalTime end) {
        ZonedDateTime local = now.atZone(zone);
        ZonedDateTime candidate = local.toLocalDate().atTime(end).atZone(zone);
        if (!candidate.isAfter(local)) {
            candidate = candidate.plusDays(1);
        }
        return candidate.toInstant();
    }

    /** Bước đầu tiên chặn việc gửi push, theo thứ tự của flowchart "Cổng gửi thông báo". */
    public enum Gate { STORE_ONLY, QUIET_HOURS, TRY_SEND }

    public static Gate gate(boolean pushEnabled, int deviceCount, boolean quiet) {
        if (!pushEnabled || deviceCount == 0) {
            return Gate.STORE_ONLY;
        }
        return quiet ? Gate.QUIET_HOURS : Gate.TRY_SEND;
    }
}
