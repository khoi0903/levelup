package vn.levelup.engagement.rules;

import java.time.Duration;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;
import java.util.List;

/** Giờ gửi nhắc check-in và nhắc trước buổi tập, theo giờ người dùng. Không đọc database, để unit test. */
public final class ReminderRules {

    public static final LocalTime DEFAULT_CHECKIN = LocalTime.of(7, 30);
    /** Quá 3 tiếng sau giờ check-in thì thôi nhắc: nhắc muộn gây phiền hơn là giúp. */
    public static final Duration CHECKIN_WINDOW = Duration.ofHours(3);
    public static final int DEFAULT_PRE_WORKOUT_MINUTES = 60;

    /**
     * Mốc nhắc uống nước: trưa (11:00–13:00) nếu chưa tới 40% mục tiêu,
     * chiều (16:00–18:00) nếu chưa tới 70%. Ngoài khung giờ thì thôi, không nhắc dồn.
     */
    public record WaterSlot(String key, LocalTime from, LocalTime to, double minShare) {}

    public static final List<WaterSlot> WATER_SLOTS = List.of(
        new WaterSlot("noon", LocalTime.of(11, 0), LocalTime.of(13, 0), 0.4),
        new WaterSlot("afternoon", LocalTime.of(16, 0), LocalTime.of(18, 0), 0.7));

    private ReminderRules() {}

    /** "07:30" → 07:30; sai định dạng hoặc thiếu thì dùng mặc định. */
    public static LocalTime time(String value, LocalTime fallback) {
        if (value == null || value.isBlank()) {
            return fallback;
        }
        try {
            return LocalTime.parse(value);
        } catch (DateTimeParseException e) {
            return fallback;
        }
    }

    /** Đã tới giờ nhắc check-in và còn trong cửa sổ 3 tiếng (không vắt qua nửa đêm). */
    public static boolean checkinDue(LocalTime now, LocalTime checkinAt) {
        LocalTime end = checkinAt.plus(CHECKIN_WINDOW);
        boolean wraps = end.isBefore(checkinAt);
        return !now.isBefore(checkinAt) && (wraps || now.isBefore(end));
    }

    /** Mốc nhắc uống nước đang tới hạn, hoặc null (đã uống đủ, ngoài khung giờ, chưa có mục tiêu). */
    public static WaterSlot waterDue(LocalTime now, int drankMl, int targetMl) {
        if (targetMl <= 0) {
            return null;
        }
        for (WaterSlot s : WATER_SLOTS) {
            if (!now.isBefore(s.from()) && now.isBefore(s.to())) {
                return drankMl < targetMl * s.minShare() ? s : null;
            }
        }
        return null;
    }

    /** Trong khoảng [giờ tập - minutes, giờ tập): nhắc một lần trước buổi. */
    public static boolean preWorkoutDue(LocalDateTime now, LocalDateTime sessionAt, int minutes) {
        return !now.isBefore(sessionAt.minusMinutes(Math.max(0, minutes))) && now.isBefore(sessionAt);
    }
}
