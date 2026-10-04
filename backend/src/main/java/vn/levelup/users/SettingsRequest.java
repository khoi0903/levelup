package vn.levelup.users;

import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import vn.levelup.onboarding.OnboardingRequest;

/**
 * PATCH /me: chỉ đổi những trường được gửi (null = giữ nguyên). Giá trị enum khớp validator users.
 * Đổi lịch rảnh hoặc thời lượng buổi chỉ áp dụng cho kế hoạch các tuần sau, không sửa tuần đang tập.
 */
public record SettingsRequest(
    @Size(min = 1, max = 60) @Pattern(regexp = ".*\\S.*") String displayName,
    @Size(max = 64) String timezone,
    @Pattern(regexp = "strict|supportive|funny") String coachStyle,
    @Min(5) @Max(180) Integer sessionMinutes,
    @Size(min = 1, max = 7) List<OnboardingRequest.@Valid Slot> availability,
    @Valid Notifications notifications,
    Sharing sharing
) {
    private static final String HH_MM = "([01]\\d|2[0-3]):[0-5]\\d";

    public record Notifications(
        Boolean pushEnabled,
        @Pattern(regexp = HH_MM) String checkinTime,
        @Min(0) @Max(180) Integer preWorkoutMinutes,
        @Pattern(regexp = HH_MM) String quietStart,
        @Pattern(regexp = HH_MM) String quietEnd,
        @Min(0) @Max(5) Integer maxPerDay
    ) {}

    /** Buddy được xem gì; mặc định tắt hết (chỉ thấy trạng thái tập). */
    public record Sharing(Boolean weight, Boolean measurements, Boolean photos, Boolean meals) {}
}
