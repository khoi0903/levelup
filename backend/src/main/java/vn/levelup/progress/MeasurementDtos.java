package vn.levelup.progress;

import java.util.List;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Pattern;

/** Request/response của POST /measurements và GET /measurements. */
public final class MeasurementDtos {

    private MeasurementDtos() {}

    /** Ít nhất một chỉ số. measuredOn "YYYY-MM-DD" theo ngày của người dùng, bỏ trống là hôm nay. */
    public record MeasurementRequest(
        @DecimalMin("20") @DecimalMax("350") Double weightKg,
        @DecimalMin("30") @DecimalMax("250") Double waistCm,
        @DecimalMin("30") @DecimalMax("250") Double hipCm,
        @DecimalMin("30") @DecimalMax("250") Double chestCm,
        @DecimalMin("10") @DecimalMax("100") Double armCm,
        @DecimalMin("2") @DecimalMax("75") Double bodyFatPct,
        @Pattern(regexp = "\\d{4}-\\d{2}-\\d{2}") String measuredOn
    ) {}

    public record MeasurementView(String measuredOn, Double weightKg, Double waistCm, Double hipCm, Double chestCm,
                                  Double armCm, Double bodyFatPct) {}

    public record Achievement(String code, String nameVi, String descriptionVi) {}

    public record SaveResponse(MeasurementView measurement, List<Achievement> newAchievements) {}

    /** Dữ liệu vẽ biểu đồ, cũ trước mới sau. */
    public record ListResponse(int days, List<MeasurementView> items) {}
}
