package vn.levelup.identity.dto;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * PATCH /me: chỉ đổi những trường được gửi (null = giữ nguyên). Giá trị enum khớp validator users.
 * Đổi mục tiêu thì tính lại calo từ hôm nay. Đổi thời lượng buổi hoặc mục tiêu chỉ áp dụng cho kế hoạch các tuần sau.
 * Đổi lịch rảnh: áp dụng ngay cho các ngày còn lại của tuần này (thêm buổi ngày mới, bỏ buổi chưa tập ở ngày bị bỏ).
 * Đổi nơi tập / dụng cụ: bài gợi ý (tập thêm, đổi bài) dùng ngay; lịch tuần đang tập giữ nguyên, tuần sau xếp theo dụng cụ mới.
 * Đổi chiều cao / cân nặng: tính lại mục tiêu calo từ hôm nay; cân nặng ghi thành số đo của hôm nay
 * (profile.startWeightKg là mốc ban đầu, giữ nguyên).
 * equipment = [] nghĩa là không có dụng cụ (khác null = giữ nguyên).
 */
public record SettingsRequest(
    @Size(min = 1, max = 60) @Pattern(regexp = ".*\\S.*") String displayName,
    @Size(max = 64) String timezone,
    @Pattern(regexp = "strict|supportive|funny") String coachStyle,
    @Pattern(regexp = "lose_fat|build_muscle|get_healthier|maintain") String goal,
    @Min(5) @Max(180) Integer sessionMinutes,
    @Pattern(regexp = "home|gym|outdoor") String location,
    @Size(max = 10) List<@Pattern(regexp = "dumbbell|mat|resistance_band|pullup_bar") String> equipment,
    @Size(min = 1, max = 7) List<OnboardingRequest.@Valid Slot> availability,
    @Valid Notifications notifications,
    Sharing sharing,
    @Min(5) @Max(50) Integer bodyFatPct,
    /** Nhóm cơ muốn tập trung; [] = bỏ chọn hết (khác null = giữ nguyên). */
    @Size(max = 7) List<@Pattern(regexp = "chest|back|shoulders|arms|abs|glutes|legs") String> focusMuscles,
    @DecimalMin("80") @DecimalMax("250") Double heightCm,
    /** Cân nặng hiện tại: ghi vào body_measurements của hôm nay và tính lại mục tiêu calo. */
    @DecimalMin("20") @DecimalMax("350") Double weightKg
) {
    private static final String HH_MM = "([01]\\d|2[0-3]):[0-5]\\d";

    public record Notifications(
        Boolean pushEnabled,
        @Pattern(regexp = HH_MM) String checkinTime,
        @Min(0) @Max(180) Integer preWorkoutMinutes,
        @Pattern(regexp = HH_MM) String quietStart,
        @Pattern(regexp = HH_MM) String quietEnd,
        @Min(0) @Max(5) Integer maxPerDay,
        Boolean waterReminder
    ) {}

    /** Buddy được xem gì; mặc định tắt hết (chỉ thấy trạng thái tập). */
    public record Sharing(Boolean weight, Boolean measurements, Boolean photos, Boolean meals) {}
}
