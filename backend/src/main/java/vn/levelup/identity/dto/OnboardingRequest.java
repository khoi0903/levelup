package vn.levelup.identity.dto;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Dữ liệu 9 màn onboarding (F1). Giá trị enum khớp validator collection users. */
public record OnboardingRequest(
    @NotBlank @Size(max = 60) String displayName,
    @NotNull @Pattern(regexp = "lose_fat|build_muscle|get_healthier|maintain") String goal,
    @Pattern(regexp = "male|female|other") String gender,
    @Min(1900) @Max(2100) Integer birthYear,
    @NotNull @DecimalMin("80") @DecimalMax("250") Double heightCm,
    @NotNull @DecimalMin("20") @DecimalMax("350") Double weightKg,
    @DecimalMin("20") @DecimalMax("350") Double goalWeightKg,
    @NotNull @Pattern(regexp = "beginner|intermediate|regular") String experience,
    @NotNull @Pattern(regexp = "home|gym|outdoor") String location,
    List<@Pattern(regexp = "dumbbell|mat|resistance_band|pullup_bar") String> equipment,
    List<@Pattern(regexp = "lower_back|knee|shoulder|neck|wrist|ankle|hip|other") String> injuries,
    @NotEmpty List<@Valid Slot> availability,
    @NotNull @Min(5) @Max(180) Integer sessionMinutes,
    @Size(max = 10) List<@Size(max = 40) String> motivationReasons,
    @Size(max = 500) String motivationText,
    @NotNull @Pattern(regexp = "strict|supportive|funny") String coachStyle,
    String timezone,
    /** Tỉ lệ mỡ cơ thể người dùng tự chọn (5–50%), không bắt buộc. */
    @Min(5) @Max(50) Integer bodyFatPct,
    /** Nhóm cơ muốn tập trung, không bắt buộc; trùng thì gộp. */
    @Size(max = 7) List<@Pattern(regexp = "chest|back|shoulders|arms|abs|glutes|legs") String> focusMuscles
) {
    public record Slot(
        @NotNull @Min(1) @Max(7) Integer weekday,
        @NotNull @Pattern(regexp = "early_morning|noon|evening|late_evening") String slot,
        /** Giờ tập riêng của ngày này "HH:mm", không bắt buộc; có thì thắng giờ mặc định của khung. */
        @Pattern(regexp = "([01]\\d|2[0-3]):[0-5]\\d") String time
    ) {
        public Slot(Integer weekday, String slot) {
            this(weekday, slot, null);
        }
    }
}
