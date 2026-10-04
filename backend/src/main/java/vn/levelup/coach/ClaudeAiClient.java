package vn.levelup.coach;

import java.time.Duration;
import java.util.Base64;
import java.util.List;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.anthropic.client.AnthropicClient;
import com.anthropic.client.okhttp.AnthropicOkHttpClient;
import com.anthropic.errors.AnthropicException;
import com.anthropic.models.messages.Base64ImageSource;
import com.anthropic.models.messages.ContentBlockParam;
import com.anthropic.models.messages.ImageBlockParam;
import com.anthropic.models.messages.MessageCreateParams;
import com.anthropic.models.messages.MessageParam;
import com.anthropic.models.messages.OutputConfig;
import com.anthropic.models.messages.StopReason;
import com.anthropic.models.messages.TextBlockParam;

/** AiClient gọi Claude qua SDK chính thức. Bean được tạo trong AiConfig. */
public class ClaudeAiClient implements AiClient {

    private static final Logger log = LoggerFactory.getLogger(ClaudeAiClient.class);

    private final AnthropicClient client;
    private final String model;

    public ClaudeAiClient(String model, int timeoutSeconds) {
        this.model = model;
        String key = System.getenv("ANTHROPIC_API_KEY");
        // Hết 20 giây thì báo bận, thử lại 1 lần (docs/04-backend-flow.html, mục Lỗi và mất mạng)
        this.client = key == null || key.isBlank() ? null : AnthropicOkHttpClient.builder()
            .apiKey(key).timeout(Duration.ofSeconds(timeoutSeconds)).maxRetries(1).build();
    }

    @Override
    public boolean available() {
        return client != null;
    }

    @Override
    public String complete(String system, List<AiClient.Message> messages, int maxTokens) {
        MessageCreateParams.Builder params = base(system, maxTokens);
        for (AiClient.Message m : messages) {
            params.addMessage(MessageParam.builder()
                .role("assistant".equals(m.role()) ? MessageParam.Role.ASSISTANT : MessageParam.Role.USER)
                .content(m.text()).build());
        }
        return call(params.build());
    }

    @Override
    public String completeWithImage(String system, String prompt, byte[] image, String mediaType, int maxTokens) {
        ImageBlockParam img = ImageBlockParam.builder()
            .source(Base64ImageSource.builder()
                .data(Base64.getEncoder().encodeToString(image))
                .mediaType(Base64ImageSource.MediaType.of(mediaType))
                .build())
            .build();
        MessageCreateParams params = base(system, maxTokens)
            .addUserMessageOfBlockParams(List.of(ContentBlockParam.ofImage(img),
                ContentBlockParam.ofText(TextBlockParam.builder().text(prompt).build())))
            .build();
        return call(params);
    }

    private MessageCreateParams.Builder base(String system, int maxTokens) {
        MessageCreateParams.Builder b = MessageCreateParams.builder()
            .model(model)
            .maxTokens(maxTokens)
            .system(system);
        // Câu trả lời ngắn cho người dùng: effort thấp đủ dùng, nhanh và rẻ.
        // Haiku 4.5 (LEVELUP_AI_MODEL=claude-haiku-4-5, rẻ cho dev) không nhận tham số effort.
        if (!model.startsWith("claude-haiku")) {
            b.outputConfig(OutputConfig.builder().effort(OutputConfig.Effort.LOW).build());
        }
        return b;
    }

    private String call(MessageCreateParams params) {
        if (client == null) {
            throw new AiUnavailableException("ANTHROPIC_API_KEY chưa được cấu hình", null);
        }
        try {
            com.anthropic.models.messages.Message response = client.messages().create(params);
            if (response.stopReason().map(StopReason.REFUSAL::equals).orElse(false)) {
                throw new AiUnavailableException("Claude từ chối trả lời", null);
            }
            return response.content().stream()
                .flatMap(b -> b.text().stream())
                .map(t -> t.text())
                .collect(Collectors.joining());
        } catch (AnthropicException e) {
            log.warn("Gọi Claude lỗi: {}", e.getMessage());
            throw new AiUnavailableException("Coach đang bận, thử lại nhé", e);
        }
    }
}
