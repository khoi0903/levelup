package vn.levelup.jobs;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

/** Giờ giấc của /jobs/tick theo giờ người dùng, không đọc hay ghi database, để unit test. */
public final class JobRules {

    /** Chốt ngày hôm qua từ 00:05 (spec F3). */
    public static final LocalTime DAY_CLOSE_AT = LocalTime.of(0, 5);
    /** Chốt tuần từ 19:00 Chủ nhật (spec F4). */
    public static final LocalTime WEEK_CLOSE_AT = LocalTime.of(19, 0);

    private JobRules() {}

    /** Ngày mới nhất được phép chốt: hôm qua nếu đã qua 00:05, không thì hôm kia. */
    public static LocalDate dayToClose(LocalDateTime local) {
        LocalDate today = local.toLocalDate();
        return local.toLocalTime().isBefore(DAY_CLOSE_AT) ? today.minusDays(2) : today.minusDays(1);
    }

    /** Đã tới giờ chốt tuần hiện tại chưa. */
    public static boolean weekCloseDue(LocalDateTime local) {
        return local.getDayOfWeek() == DayOfWeek.SUNDAY && !local.toLocalTime().isBefore(WEEK_CLOSE_AT);
    }
}
