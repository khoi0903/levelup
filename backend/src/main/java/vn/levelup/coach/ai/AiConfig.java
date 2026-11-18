package vn.levelup.coach.ai;

import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Chọn nhà cung cấp AI cho AiClient (coach, tổng kết tuần, nhận diện món ăn):
 * - levelup.ai.provider = claude | gemini | groq | auto (mặc định auto)
 * - claude / gemini / groq: chỉ dùng đúng nơi đó.
 * - auto: có ANTHROPIC_API_KEY thì Claude. Không thì nối các nơi miễn phí có key theo thứ tự
 *   Gemini (GEMINI_API_KEY) rồi Groq (GROQ_API_KEY): nơi trước hết lượt thì tự sang nơi sau.
 *   Không có key nào thì Claude (available() = false, các module tự dùng luật dự phòng).
 */
@Configuration
public class AiConfig {

    private static final Logger log = LoggerFactory.getLogger(AiConfig.class);

    @Bean
    AiClient aiClient(@Value("${levelup.ai.provider:auto}") String provider,
                      @Value("${levelup.ai.model:claude-opus-5-5}") String claudeModel,
                      @Value("${levelup.ai.gemini-model:gemini-3.5-flash}") String geminiModel,
                      @Value("${levelup.ai.groq-model:openai/gpt-oss-120b}") String groqModel,
                      @Value("${levelup.ai.timeout-seconds:20}") int timeoutSeconds) {
        String gemini = System.getenv("GEMINI_API_KEY");
        String groq = System.getenv("GROQ_API_KEY");
        List<String> chosen = choose(provider, System.getenv("ANTHROPIC_API_KEY"), gemini, groq);
        log.info("AI provider: {}", String.join(" -> ", chosen));
        List<FallbackAiClient.Named> clients = chosen.stream().map(name -> new FallbackAiClient.Named(name,
            switch (name) {
                case "gemini" -> new GeminiAiClient(gemini, geminiModel, timeoutSeconds);
                case "groq" -> new GroqAiClient(groq, groqModel, timeoutSeconds);
                default -> new ClaudeAiClient(claudeModel, timeoutSeconds);
            })).toList();
        return clients.size() == 1 ? clients.getFirst().client()
            : new FallbackAiClient(clients, Clock.systemUTC());
    }

    /** Danh sách nhà cung cấp theo thứ tự thử. */
    static List<String> choose(String provider, String anthropicKey, String geminiKey, String groqKey) {
        String p = provider == null ? "auto" : provider.trim().toLowerCase();
        if (p.equals("claude") || p.equals("gemini") || p.equals("groq")) {
            return List.of(p);
        }
        if (has(anthropicKey)) {
            return List.of("claude");
        }
        List<String> free = new ArrayList<>();
        if (has(geminiKey)) {
            free.add("gemini");
        }
        if (has(groqKey)) {
            free.add("groq");
        }
        return free.isEmpty() ? List.of("claude") : List.copyOf(free);
    }

    private static boolean has(String key) {
        return key != null && !key.isBlank();
    }
}
