package vn.levelup.coach.ai;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;

/**
 * AiClient gọi Groq (API kiểu chat/completions) qua REST, không cần thêm thư viện.
 * Dùng làm dự phòng miễn phí khi Gemini hết lượt. Chỉ văn bản: ảnh món ăn thì báo không dùng được
 * để nơi gọi chuyển sang luật cố định.
 */
public class GroqAiClient implements AiClient {

    private static final Logger log = LoggerFactory.getLogger(GroqAiClient.class);
    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final String URL = "https://api.groq.com/openai/v1/chat/completions";
    /** Model suy luận (gpt-oss) tính cả phần suy nghĩ vào giới hạn chữ; chừa thêm để câu trả lời không bị cắt. */
    static final int REASONING_HEADROOM = 1024;

    private final String apiKey;
    private final String model;
    private final Duration timeout;
    private volatile HttpClient http;

    public GroqAiClient(String apiKey, String model, int timeoutSeconds) {
        this.apiKey = apiKey == null || apiKey.isBlank() ? null : apiKey;
        this.model = model;
        this.timeout = Duration.ofSeconds(timeoutSeconds);
    }

    @Override
    public boolean available() {
        return apiKey != null;
    }

    @Override
    public String complete(String system, List<AiClient.Message> messages, int maxTokens) {
        if (apiKey == null) {
            throw new AiUnavailableException("GROQ_API_KEY chưa được cấu hình", null);
        }
        HttpRequest request = HttpRequest.newBuilder(URI.create(URL))
            .timeout(timeout)
            .header("Content-Type", "application/json")
            .header("Authorization", "Bearer " + apiKey)
            .POST(HttpRequest.BodyPublishers.ofString(
                JSON.writeValueAsString(request(model, system, messages, maxTokens)), StandardCharsets.UTF_8))
            .build();
        for (int attempt = 1; ; attempt++) {
            try {
                HttpResponse<String> response = http().send(request,
                    HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
                int status = response.statusCode();
                if (status == 200) {
                    return parseText(response.body());
                }
                log.warn("Gọi Groq lỗi HTTP {} (lần {})", status, attempt);
                if (status == 429) {
                    throw new RateLimitedException("Groq hết lượt");
                }
                if (status == 503) {
                    throw new ProviderDownException("Groq quá tải", null);
                }
                if (status < 500 || attempt >= 2) {
                    throw new AiUnavailableException("Coach đang bận, thử lại nhé", null);
                }
            } catch (java.net.http.HttpTimeoutException e) {
                log.warn("Gọi Groq quá giờ chờ: {}", e.getMessage());
                throw new ProviderDownException("Groq quá giờ chờ", e);
            } catch (IOException e) {
                log.warn("Gọi Groq lỗi mạng (lần {}): {}", attempt, e.getMessage());
                if (attempt >= 2) {
                    throw new AiUnavailableException("Coach đang bận, thử lại nhé", e);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new AiUnavailableException("Bị ngắt khi gọi Groq", e);
            }
        }
    }

    @Override
    public String completeWithImage(String system, String prompt, byte[] image, String mediaType, int maxTokens) {
        throw new AiUnavailableException("Groq không dùng cho ảnh món ăn", null);
    }

    static ObjectNode request(String model, String system, List<AiClient.Message> messages, int maxTokens) {
        ObjectNode body = JSON.createObjectNode();
        body.put("model", model);
        boolean reasoning = model != null && model.startsWith("openai/gpt-oss");
        body.put("max_completion_tokens", maxTokens + (reasoning ? REASONING_HEADROOM : 0));
        if (reasoning) {
            body.put("reasoning_effort", "low");
        }
        ArrayNode list = body.putArray("messages");
        if (system != null && !system.isBlank()) {
            list.addObject().put("role", "system").put("content", system);
        }
        for (AiClient.Message m : messages) {
            list.addObject().put("role", "assistant".equals(m.role()) ? "assistant" : "user").put("content", m.text());
        }
        return body;
    }

    static String parseText(String responseBody) {
        JsonNode content = JSON.readTree(responseBody).path("choices").path(0).path("message").path("content");
        String text = content.isString() ? plain(content.asString()).strip() : "";
        if (text.isEmpty()) {
            throw new AiUnavailableException("Groq không trả nội dung", null);
        }
        return text;
    }

    /**
     * App hiện chữ thường, không hiểu markdown: bỏ dấu in đậm/nghiêng (**, __) và dấu tiêu đề (#)
     * mà model của Groq hay thêm, giữ nguyên danh sách đánh số và gạch đầu dòng.
     */
    static String plain(String text) {
        return text.replace("**", "").replace("__", "")
            .replaceAll("(?m)^#{1,6}\\s+", "");
    }

    private HttpClient http() {
        if (http == null) {
            synchronized (this) {
                if (http == null) {
                    http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
                }
            }
        }
        return http;
    }
}
