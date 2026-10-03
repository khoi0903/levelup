package vn.levelup.buddies;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** type: nudge (nhắc bạn tập) | cheer (cổ vũ). message: lời nhắn ngắn, không bắt buộc. */
public record ActionRequest(
    @NotNull @Pattern(regexp = "nudge|cheer") String type,
    @Size(max = 140) String message
) {}
