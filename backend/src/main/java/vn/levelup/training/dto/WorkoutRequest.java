package vn.levelup.training.dto;

import java.time.Instant;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Buổi tập app gửi lên sau khi tập xong (F2, F2b). Giá trị enum khớp validator workout_logs.
 * clientId do app sinh khi bắt đầu buổi, dùng để app gửi lại khi mất mạng mà không lưu trùng.
 */
public record WorkoutRequest(
    @NotNull @Pattern(regexp = "[A-Za-z0-9_-]{8,64}") String clientId,
    @Pattern(regexp = "[0-9a-f]{24}") String plannedSessionId,
    @NotNull Instant startedAt,
    @NotNull Instant endedAt,
    @NotNull @Pattern(regexp = "normal|light|quick5|advanced") String variant,
    @Min(1) @Max(10) Integer rpe,
    List<@Pattern(regexp = "lower_back|knee|shoulder|neck|wrist|ankle|hip|other") String> painAreas,
    /** soreness: mỏi cơ (không đổi lịch). sharp: đau nhói/khớp (theo dõi, hỏi thăm hôm sau). Thiếu: như cũ. */
    @Pattern(regexp = "soreness|sharp") String painType,
    @Size(max = 500) String note,
    @NotEmpty @Size(max = 200) List<@Valid @NotNull SetLog> sets
) {
    public record SetLog(
        @NotNull @Pattern(regexp = "[0-9a-f]{24}") String exerciseId,
        @NotNull @Min(1) Integer setIndex,
        @Min(0) @Max(1000) Integer reps,
        @DecimalMin("0") @DecimalMax("500") Double weightKg,
        @Min(0) @Max(7200) Integer durationSec,
        @Pattern(regexp = "manual|camera|camera_corrected") String repSource,
        @Min(0) @Max(1000) Integer repsDetected,
        @Min(1) Integer cvVersion,
        @DecimalMin("0") @DecimalMax("1") Double avgConfidence,
        @Min(0) @Max(100) Integer formScore,
        @Size(max = 100) List<@Valid @NotNull FormIssue> formIssues
    ) {}

    public record FormIssue(
        @NotNull @Min(1) Integer repIndex,
        @NotNull @Pattern(regexp = "[a-z_]{1,40}") String code,
        @NotNull @Min(1) @Max(3) Integer severity
    ) {}
}
