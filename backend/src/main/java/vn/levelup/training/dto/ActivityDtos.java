package vn.levelup.training.dto;

import java.time.Instant;
import java.util.List;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

/** Hoạt động trong ngày đọc từ Health Connect trên điện thoại (số bước, calo vận động). */
public final class ActivityDtos {

    private ActivityDtos() {}

    /**
     * localDate: ngày điện thoại đã đọc số liệu (từ 0h tới lúc gửi). Chỉ lưu khi trùng "hôm nay" của máy chủ,
     * để không tin giờ điện thoại.
     * activeKcalInWorkouts: phần calo vận động Health Connect ghi trong lúc tập trong app (theo workoutWindows của
     * GET /activity/today), để cộng calo buổi tập mà không tính trùng. null: app cũ không gửi.
     */
    public record ActivityRequest(
        @NotNull @Pattern(regexp = "\\d{4}-\\d{2}-\\d{2}") String localDate,
        @NotNull @Min(0) @Max(200_000) Integer steps,
        @NotNull @Min(0) @Max(10_000) Integer activeKcal,
        @Min(0) @Max(10_000) Integer activeKcalInWorkouts
    ) {}

    /** stored = false khi localDate khác hôm nay của máy chủ (vừa qua nửa đêm...), app bỏ qua. */
    public record ActivityView(String localDate, int steps, int activeKcal, boolean stored) {}

    /** Một buổi tập trong app hôm nay (giờ bắt đầu/kết thúc máy chủ đã lưu). */
    public record WorkoutWindow(Instant startedAt, Instant endedAt) {}

    /**
     * GET /activity/today: số đã lưu trên máy chủ (lớn nhất giữa các điện thoại của tài khoản) và các buổi tập
     * hôm nay để app tính activeKcalInWorkouts.
     */
    public record TodayView(String localDate, int steps, int activeKcal, List<WorkoutWindow> workoutWindows) {}

    /** Một ngày trong lịch sử: số bước, calo vận động (Health Connect), calo buổi tập trong app và tổng. */
    public record DayView(String localDate, int steps, int activeKcal, int workoutKcal, int totalBurnedKcal) {}

    /** GET /activity/history: các ngày từ cũ tới mới, kể cả ngày không có dữ liệu (số 0). */
    public record HistoryView(List<DayView> days) {}
}
