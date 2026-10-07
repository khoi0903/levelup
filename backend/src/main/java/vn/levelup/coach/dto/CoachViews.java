package vn.levelup.coach.dto;

import java.time.Instant;
import java.util.List;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import vn.levelup.training.dto.PlanView;

/** Request và response của /coach/messages. */
public final class CoachViews {

    private CoachViews() {}

    public record SendRequest(@NotBlank @Size(min = 1, max = 1000) String text) {}

    /**
     * Kết quả gửi tin: tin của người dùng, tin trả lời của coach (có thể kèm thẻ hành động),
     * số lượt còn lại hôm nay, nguồn trả lời: "ai" hoặc "rules" (không có AI, dùng luật cố định).
     */
    public record SendResponse(MessageView userMessage, MessageView reply, int remainingToday, String source) {}

    /** role: user | coach | event. */
    public record MessageView(String id, String role, String content, Instant createdAt, CardView card) {}

    /**
     * Thẻ hành động: type adjust_session (đổi một buổi, có thể kèm ghi nhận chấn thương) hoặc add_injury.
     * status: proposed → applied. preview: buổi tập sau khi áp dụng, chỉ có ngay trong response của POST.
     */
    public record CardView(String type, String status, String planId, String sessionId, String change,
                           String fromExerciseId, String fromExerciseName, String toExerciseId,
                           String toExerciseName, String reason, InjuryView injury,
                           PlanView.SessionView preview) {}

    public record InjuryView(String bodyArea, String note) {}

    /** Trang lịch sử, mới nhất trước. nextBefore: truyền vào ?before= để lấy trang cũ hơn, null khi hết. */
    /** remainingToday: số tin còn gửi được hôm nay (để màn Coach hiện đúng ngay khi mở). */
    public record HistoryResponse(List<MessageView> messages, Instant nextBefore, int remainingToday) {}
}
