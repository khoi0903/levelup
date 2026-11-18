package vn.levelup.coach.ai;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.List;
import java.util.function.Consumer;
import java.util.stream.Stream;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;

/**
 * AiClient gọi Google Gemini qua REST (generateContent), không cần thêm thư viện.
 * Bật bằng LEVELUP_AI_PROVIDER=gemini + GEMINI_API_KEY (xem AiConfig).
 * Lưu ý: gói miễn phí của Gemini được Google dùng dữ liệu để cải thiện sản phẩm —
 * chỉ dùng với dữ liệu thử, người dùng thật thì dùng gói trả phí.
 */
public class GeminiAiClient implements AiClient {

    private static final Logger log = LoggerFactory.getLogger(GeminiAiClient.class);
    private static final JsonMapper JSON = JsonMapper.builder().build();
    private static final String BASE = "https://generativelanguage.googleapis.com/v1beta/models/";
    /** Model 2.5+ dùng một phần maxOutputTokens để suy nghĩ; chừa thêm để câu trả lời không bị cắt rỗng. */
    static final int THINKING_HEADROOM = 2048;

    private final String apiKey;
    private final String model;
    private final Duration timeout;
    /** Tạo khi gọi lần đầu: không có key thì không mở kết nối nào. */
    private volatile HttpClient http;

    public GeminiAiClient(String apiKey, String model, int timeoutSeconds) {
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
        return call(textRequest(system, messages, maxTokens));
    }

    /**
     * streamGenerateContent?alt=sse: mỗi dòng "data: {...}" là một phần câu trả lời.
     * Lỗi trước khi có chữ nào thì thử lại 1 lần như complete; đã phát chữ rồi mà đứt thì báo AI lỗi.
     */
    @Override
    public String stream(String system, List<AiClient.Message> messages, int maxTokens, Consumer<String> onText) {
        if (apiKey == null) {
            throw new AiUnavailableException("GEMINI_API_KEY chưa được cấu hình", null);
        }
        HttpRequest request = HttpRequest.newBuilder(URI.create(BASE + model + ":streamGenerateContent?alt=sse"))
            .timeout(timeout)
            .header("Content-Type", "application/json")
            .header("x-goog-api-key", apiKey)
            .POST(HttpRequest.BodyPublishers.ofString(JSON.writeValueAsString(textRequest(system, messages, maxTokens)),
                StandardCharsets.UTF_8))
            .build();
        for (int attempt = 1; ; attempt++) {
            StringBuilder all = new StringBuilder();
            try {
                HttpResponse<Stream<String>> response = http().send(request,
                    HttpResponse.BodyHandlers.ofLines());
                int status = response.statusCode();
                if (status != 200) {
                    response.body().close();
                    log.warn("Gọi Gemini (stream) lỗi HTTP {} (lần {})", status, attempt);
                    if (status == 429) {
                        // Hết lượt (gói miễn phí theo phút/ngày): thử lại chỉ tốn thêm lượt
                        throw new RateLimitedException("Gemini hết lượt");
                    }
                    if (status == 503) {
                        throw new ProviderDownException("Gemini quá tải", null);
                    }
                    if (status < 500 || attempt >= 2) {
                        throw new AiUnavailableException("Coach đang bận, thử lại nhé", null);
                    }
                    continue;
                }
                try (Stream<String> lines = response.body()) {
                    lines.filter(l -> l.startsWith("data:")).forEach(l -> {
                        String part = parseChunk(l.substring(5).trim());
                        if (!part.isEmpty()) {
                            all.append(part);
                            onText.accept(part);
                        }
                    });
                }
                if (all.isEmpty()) {
                    throw new AiUnavailableException("Gemini không trả nội dung (stream)", null);
                }
                return all.toString();
            } catch (java.net.http.HttpTimeoutException e) {
                // Quá giờ chờ: thử lại thường cũng chậm, người dùng đã đợi 20 giây rồi
                log.warn("Gọi Gemini (stream) quá giờ chờ: {}", e.getMessage());
                throw new ProviderDownException("Gemini quá giờ chờ", e);
            } catch (IOException | UncheckedIOException e) {
                log.warn("Gọi Gemini (stream) lỗi mạng (lần {}): {}", attempt, e.getMessage());
                if (!all.isEmpty() || attempt >= 2) {
                    throw new AiUnavailableException("Coach đang bận, thử lại nhé", e);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new AiUnavailableException("Bị ngắt khi gọi Gemini", e);
            }
        }
    }

    /** Chữ trong một sự kiện stream (bỏ phần "thought"); bị chặn thì coi như AI không dùng được. */
    static String parseChunk(String json) {
        if (json.isEmpty()) {
            return "";
        }
        JsonNode root = JSON.readTree(json);
        JsonNode blocked = root.path("promptFeedback").path("blockReason");
        if (!blocked.isMissingNode() && !blocked.isNull()) {
            throw new AiUnavailableException("Gemini chặn yêu cầu: " + blocked.asString(), null);
        }
        StringBuilder text = new StringBuilder();
        for (JsonNode part : root.path("candidates").path(0).path("content").path("parts")) {
            if (!part.path("thought").asBoolean(false) && part.path("text").isString()) {
                text.append(part.path("text").asString());
            }
        }
        return text.toString();
    }

    @Override
    public String completeWithImage(String system, String prompt, byte[] image, String mediaType, int maxTokens) {
        return call(imageRequest(system, prompt, image, mediaType, maxTokens));
    }

    private String call(ObjectNode body) {
        if (apiKey == null) {
            throw new AiUnavailableException("GEMINI_API_KEY chưa được cấu hình", null);
        }
        HttpRequest request = HttpRequest.newBuilder(URI.create(BASE + model + ":generateContent"))
            .timeout(timeout)
            .header("Content-Type", "application/json")
            .header("x-goog-api-key", apiKey)
            .POST(HttpRequest.BodyPublishers.ofString(JSON.writeValueAsString(body), StandardCharsets.UTF_8))
            .build();
        // Lỗi tạm thời (5xx, mạng) thử lại 1 lần; 429 (hết lượt) chuyển sang nhà cung cấp dự phòng
        for (int attempt = 1; ; attempt++) {
            try {
                HttpResponse<String> response = http().send(request,
                    HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
                int status = response.statusCode();
                if (status == 200) {
                    return parseText(response.body());
                }
                log.warn("Gọi Gemini lỗi HTTP {} (lần {})", status, attempt);
                if (status == 429) {
                    throw new RateLimitedException("Gemini hết lượt");
                }
                if (status == 503) {
                    throw new ProviderDownException("Gemini quá tải", null);
                }
                if (status < 500 || attempt >= 2) {
                    throw new AiUnavailableException("Coach đang bận, thử lại nhé", null);
                }
            } catch (java.net.http.HttpTimeoutException e) {
                log.warn("Gọi Gemini quá giờ chờ: {}", e.getMessage());
                throw new ProviderDownException("Gemini quá giờ chờ", e);
            } catch (IOException e) {
                log.warn("Gọi Gemini lỗi mạng (lần {}): {}", attempt, e.getMessage());
                if (attempt >= 2) {
                    throw new AiUnavailableException("Coach đang bận, thử lại nhé", e);
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                throw new AiUnavailableException("Bị ngắt khi gọi Gemini", e);
            }
        }
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

    static ObjectNode textRequest(String system, List<AiClient.Message> messages, int maxTokens) {
        ObjectNode body = base(system, maxTokens);
        ArrayNode contents = body.putArray("contents");
        for (AiClient.Message m : messages) {
            ObjectNode content = contents.addObject();
            // Gemini gọi vai trả lời là "model" thay vì "assistant"
            content.put("role", "assistant".equals(m.role()) ? "model" : "user");
            content.putArray("parts").addObject().put("text", m.text());
        }
        return body;
    }

    static ObjectNode imageRequest(String system, String prompt, byte[] image, String mediaType, int maxTokens) {
        ObjectNode body = base(system, maxTokens);
        ObjectNode content = body.putArray("contents").addObject();
        content.put("role", "user");
        ArrayNode parts = content.putArray("parts");
        ObjectNode inline = parts.addObject().putObject("inlineData");
        inline.put("mimeType", mediaType);
        inline.put("data", Base64.getEncoder().encodeToString(image));
        parts.addObject().put("text", prompt);
        return body;
    }

    private static ObjectNode base(String system, int maxTokens) {
        ObjectNode body = JSON.createObjectNode();
        body.putObject("systemInstruction").putArray("parts").addObject().put("text", system);
        body.putObject("generationConfig").put("maxOutputTokens", maxTokens + THINKING_HEADROOM);
        return body;
    }

    /** Ghép các phần text của ứng viên đầu; bị chặn hoặc rỗng thì coi như AI không dùng được. */
    static String parseText(String responseBody) {
        JsonNode root = JSON.readTree(responseBody);
        JsonNode blocked = root.path("promptFeedback").path("blockReason");
        if (!blocked.isMissingNode() && !blocked.isNull()) {
            throw new AiUnavailableException("Gemini chặn yêu cầu: " + blocked.asString(), null);
        }
        JsonNode candidate = root.path("candidates").path(0);
        StringBuilder text = new StringBuilder();
        for (JsonNode part : candidate.path("content").path("parts")) {
            if (part.path("thought").asBoolean(false)) {
                continue;
            }
            JsonNode t = part.path("text");
            if (t.isString()) {
                text.append(t.asString());
            }
        }
        if (text.isEmpty()) {
            String reason = candidate.path("finishReason").asString("UNKNOWN");
            throw new AiUnavailableException("Gemini không trả nội dung (" + reason + ")", null);
        }
        return text.toString();
    }
}
