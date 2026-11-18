package vn.levelup.coach.ai;

import java.util.List;
import java.util.function.Consumer;

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

    /**
     * Như {@link #complete}, nhưng gọi onText với từng đoạn chữ mới khi AI trả dần, rồi trả toàn bộ chữ.
     * Mặc định (nhà cung cấp chưa hỗ trợ stream): gọi complete rồi phát một lần.
     */
    default String stream(String system, List<Message> messages, int maxTokens, Consumer<String> onText) {
        String all = complete(system, messages, maxTokens);
        onText.accept(all);
        return all;
    }

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

    /** Nhà cung cấp báo hết lượt (HTTP 429): không thử lại cùng nơi, chuyển sang nhà cung cấp dự phòng. */
    class RateLimitedException extends AiUnavailableException {
        public RateLimitedException(String message) { super(message, null); }
    }

    /** Nhà cung cấp quá tải (503) hoặc quá giờ chờ: không thử lại cùng nơi, chuyển ngay sang nơi dự phòng. */
    class ProviderDownException extends AiUnavailableException {
        public ProviderDownException(String message, Throwable cause) { super(message, cause); }
    }
}
