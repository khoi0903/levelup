package vn.levelup.coach.ai;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Consumer;
import java.util.function.Function;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Gọi lần lượt nhiều nhà cung cấp (ví dụ Gemini rồi Groq): nơi đầu lỗi thì thử nơi sau.
 * Nơi nào báo hết lượt (429) thì bỏ qua nó trong {@link #COOLDOWN} để không tốn thêm lượt gọi thừa.
 * Tất cả đều lỗi thì ném lỗi cuối, nơi gọi dùng luật cố định như trước.
 */
public class FallbackAiClient implements AiClient {

    private static final Logger log = LoggerFactory.getLogger(FallbackAiClient.class);
    static final Duration COOLDOWN = Duration.ofMinutes(10);

    /** name: tên để ghi log ("gemini", "groq"). */
    public record Named(String name, AiClient client) {}

    private final List<Named> chain;
    private final Clock clock;
    private final Map<String, Instant> resting = new ConcurrentHashMap<>();

    public FallbackAiClient(List<Named> chain, Clock clock) {
        this.chain = chain.stream().filter(n -> n.client().available()).toList();
        this.clock = clock;
    }

    @Override
    public boolean available() {
        return !chain.isEmpty();
    }

    @Override
    public String complete(String system, List<Message> messages, int maxTokens) {
        return each(c -> c.complete(system, messages, maxTokens));
    }

    /** Chỉ chuyển nơi khác khi chưa phát chữ nào; đã phát một phần rồi mà đứt thì báo lỗi (tránh lặp chữ). */
    @Override
    public String stream(String system, List<Message> messages, int maxTokens, Consumer<String> onText) {
        boolean[] started = {false};
        Consumer<String> tracked = part -> {
            started[0] = true;
            onText.accept(part);
        };
        return each(c -> {
            if (started[0]) {
                throw new AiUnavailableException("Coach đang bận, thử lại nhé", null);
            }
            return c.stream(system, messages, maxTokens, tracked);
        });
    }

    @Override
    public String completeWithImage(String system, String prompt, byte[] image, String mediaType, int maxTokens) {
        return each(c -> c.completeWithImage(system, prompt, image, mediaType, maxTokens));
    }

    private String each(Function<AiClient, String> call) {
        AiUnavailableException last = null;
        Instant now = clock.instant();
        for (Named n : chain) {
            Instant until = resting.get(n.name());
            if (until != null && now.isBefore(until)) {
                continue;
            }
            try {
                return call.apply(n.client());
            } catch (RateLimitedException e) {
                resting.put(n.name(), now.plus(COOLDOWN));
                log.info("AI {} hết lượt, tạm dùng nhà cung cấp sau trong {} phút", n.name(), COOLDOWN.toMinutes());
                last = e;
            } catch (AiUnavailableException e) {
                last = e;
            }
        }
        throw last != null ? last : new AiUnavailableException("Các nhà cung cấp AI đều đang hết lượt", null);
    }
}
