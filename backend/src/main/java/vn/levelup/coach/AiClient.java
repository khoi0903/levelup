package vn.levelup.coach;

import java.util.List;

/**
 * Cổng duy nhất gọi Claude (AGENTS.md: chỉ backend gọi AI). Mọi module dùng interface này,
 * không tự tạo client. AI không ghi database: nơi gọi kiểm tra kết quả rồi mới ghi.
 *
 * Khi chưa có ANTHROPIC_API_KEY hoặc Claude lỗi/quá 20 giây: ném {@link AiUnavailableException},
 * nơi gọi phải có phương án dự phòng bằng luật cố định (không bao giờ chặn việc lưu dữ liệu vì AI lỗi).
 */
public interface AiClient {

    /** Hội thoại văn bản. role của từng tin: "user" hoặc "assistant", tin cuối là "user". */
    String complete(String system, List<Message> messages, int maxTokens);

    /** Một ảnh kèm câu hỏi (nhận diện món ăn). mediaType: image/jpeg | image/png | image/webp. */
    String completeWithImage(String system, String prompt, byte[] image, String mediaType, int maxTokens);

    /** false khi chưa cấu hình key; nơi gọi dùng luật cố định luôn, không thử gọi. */
    boolean available();

    record Message(String role, String text) {
        public static Message user(String text) { return new Message("user", text); }
        public static Message assistant(String text) { return new Message("assistant", text); }
    }

    class AiUnavailableException extends RuntimeException {
        public AiUnavailableException(String message, Throwable cause) { super(message, cause); }
    }
}
