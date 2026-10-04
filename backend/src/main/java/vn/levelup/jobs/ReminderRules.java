package vn.levelup.jobs;

import java.time.Duration;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeParseException;

/** Giờ gửi nhắc check-in và nhắc trước buổi tập, theo giờ người dùng. Không đọc database, để unit test. */
public final class ReminderRules {

    public static final LocalTime DEFAULT_CHECKIN = LocalTime.of(7, 30);
    /** Quá 3 tiếng sau giờ check-in thì thôi nhắc: nhắc muộn gây phiền hơn là giúp. */
    public static final Duration CHECKIN_WINDOW = Duration.ofHours(3);
    public static final int DEFAULT_PRE_WORKOUT_MINUTES = 60;

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

    /** Trong khoảng [giờ tập - minutes, giờ tập): nhắc một lần trước buổi. */
    public static boolean preWorkoutDue(LocalDateTime now, LocalDateTime sessionAt, int minutes) {
        return !now.isBefore(sessionAt.minusMinutes(Math.max(0, minutes))) && now.isBefore(sessionAt);
    }
}
