package vn.levelup.common;

import java.time.Clock;
import java.time.DateTimeException;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.TemporalAdjusters;

/**
 * Nơi duy nhất tính "ngày" và "tuần" của người dùng (localDate, weekStart).
 * Không tự tính ngày ở chỗ khác.
 */
public final class LocalDates {

    public static final ZoneId DEFAULT_ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    private LocalDates() {}

    /** Múi giờ của người dùng; thiếu hoặc sai thì dùng giờ Việt Nam. */
    public static ZoneId zone(String timezone) {
        if (timezone == null || timezone.isBlank()) {
            return DEFAULT_ZONE;
        }
        try {
            return ZoneId.of(timezone);
        } catch (DateTimeException e) {
            return DEFAULT_ZONE;
        }
    }

    /** Hôm nay theo giờ của người dùng. */
    public static LocalDate today(String timezone, Clock clock) {
        return LocalDate.now(clock.withZone(zone(timezone)));
    }

    /** Thứ Hai của tuần chứa ngày này. */
    public static LocalDate weekStart(LocalDate date) {
        return date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY));
    }
}
