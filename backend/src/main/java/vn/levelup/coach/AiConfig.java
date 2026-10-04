package vn.levelup.coach;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Chọn nhà cung cấp AI cho AiClient (coach, tổng kết tuần, nhận diện món ăn):
 * - levelup.ai.provider = claude | gemini | auto (mặc định auto)
 * - auto: có ANTHROPIC_API_KEY thì Claude, không thì có GEMINI_API_KEY thì Gemini, không có gì thì Claude
 *   (available() = false, các module tự dùng luật dự phòng).
 */
@Configuration
public class AiConfig {

    private static final Logger log = LoggerFactory.getLogger(AiConfig.class);

    @Bean
    AiClient aiClient(@Value("${levelup.ai.provider:auto}") String provider,
                      @Value("${levelup.ai.model:claude-opus-5-5}") String claudeModel,
                      @Value("${levelup.ai.gemini-model:gemini-2.5-flash}") String geminiModel,
                      @Value("${levelup.ai.timeout-seconds:20}") int timeoutSeconds) {
        String chosen = choose(provider, System.getenv("ANTHROPIC_API_KEY"), System.getenv("GEMINI_API_KEY"));
        log.info("AI provider: {}", chosen);
        return "gemini".equals(chosen)
            ? new GeminiAiClient(System.getenv("GEMINI_API_KEY"), geminiModel, timeoutSeconds)
            : new ClaudeAiClient(claudeModel, timeoutSeconds);
    }

    static String choose(String provider, String anthropicKey, String geminiKey) {
        String p = provider == null ? "auto" : provider.trim().toLowerCase();
        if (p.equals("claude") || p.equals("gemini")) {
            return p;
        }
        if (anthropicKey != null && !anthropicKey.isBlank()) {
            return "claude";
        }
        if (geminiKey != null && !geminiKey.isBlank()) {
            return "gemini";
        }
        return "claude";
    }
}
