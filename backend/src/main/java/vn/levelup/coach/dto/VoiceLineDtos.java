package vn.levelup.coach.dto;

import java.util.List;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Câu giọng coach nói trong lúc tập (POST /coach/voice-line). AI soạn cho người dùng Pro. */
public final class VoiceLineDtos {

    private VoiceLineDtos() {}

    /**
     * situation: idle_prompt = đã lâu không đếm được lần nào, hỏi có muốn đổi bài; skipped = vừa bỏ bài.
     * formIssues: mã lỗi tư thế gần đây (vd knees_in), tối đa 5.
     */
    public record Request(
        @NotNull @Pattern(regexp = "idle_prompt|skipped") String situation,
        @NotBlank @Size(max = 100) String exerciseName,
        @Min(0) @Max(1000) Integer repsDone,
        @Min(0) @Max(1000) Integer targetReps,
        @Size(max = 5) List<@NotBlank @Size(max = 40) String> formIssues
    ) {}

    /** ai = false: câu mẫu (người dùng chưa Pro, AI lỗi/chưa cấu hình, hoặc hết lượt trong ngày). */
    public record View(String text, boolean ai) {}
}
