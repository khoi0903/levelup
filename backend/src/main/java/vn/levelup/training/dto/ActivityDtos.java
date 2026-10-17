package vn.levelup.training.dto;

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
     */
    public record ActivityRequest(
        @NotNull @Pattern(regexp = "\\d{4}-\\d{2}-\\d{2}") String localDate,
        @NotNull @Min(0) @Max(200_000) Integer steps,
        @NotNull @Min(0) @Max(10_000) Integer activeKcal
    ) {}

    /** stored = false khi localDate khác hôm nay của máy chủ (vừa qua nửa đêm...), app bỏ qua. */
    public record ActivityView(String localDate, int steps, int activeKcal, boolean stored) {}
}
