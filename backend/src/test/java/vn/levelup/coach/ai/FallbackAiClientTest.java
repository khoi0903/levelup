package vn.levelup.coach.ai;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.function.Supplier;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

class FallbackAiClientTest {

    /** Client giả: mỗi lần gọi chạy hành vi được giao, đếm số lần gọi. */
    static class Fake implements AiClient {
        final AtomicInteger calls = new AtomicInteger();
        Supplier<String> behaviour;
        final boolean available;

        Fake(boolean available, Supplier<String> behaviour) {
            this.available = available;
            this.behaviour = behaviour;
        }

        @Override
        public String complete(String system, List<Message> messages, int maxTokens) {
            calls.incrementAndGet();
            return behaviour.get();
        }

        @Override
        public String completeWithImage(String s, String p, byte[] i, String m, int t) {
            return complete(s, List.of(), t);
        }

        @Override
        public boolean available() {
            return available;
        }
    }

    private static final List<AiClient.Message> HI = List.of(AiClient.Message.user("chào"));

    @Test
    void gemini_het_luot_thi_sang_groq_va_tam_bo_qua_gemini() {
        Fake gemini = new Fake(true, () -> { throw new AiClient.RateLimitedException("429"); });
        Fake groq = new Fake(true, () -> "trả lời từ groq");
        Instant[] now = {Instant.parse("2026-11-18T07:00:00Z")};
        Clock clock = new Clock() {
            public java.time.ZoneId getZone() { return ZoneOffset.UTC; }
            public Clock withZone(java.time.ZoneId z) { return this; }
            public Instant instant() { return now[0]; }
        };
        FallbackAiClient ai = new FallbackAiClient(List.of(
            new FallbackAiClient.Named("gemini", gemini), new FallbackAiClient.Named("groq", groq)), clock);

        assertEquals("trả lời từ groq", ai.complete("s", HI, 100));
        assertEquals("trả lời từ groq", ai.complete("s", HI, 100));
        assertEquals(1, gemini.calls.get(), "đang nghỉ vì hết lượt: không gọi Gemini lần nữa");

        now[0] = now[0].plus(FallbackAiClient.COOLDOWN).plusSeconds(1);
        gemini.behaviour = () -> "gemini đã có lượt lại";
        assertEquals("gemini đã có lượt lại", ai.complete("s", HI, 100));
    }

    @Test
    void qua_tai_hoac_qua_gio_thi_nghi_ngan() {
        Fake gemini = new Fake(true, () -> { throw new AiClient.ProviderDownException("503", null); });
        Fake groq = new Fake(true, () -> "groq");
        Instant[] now = {Instant.parse("2026-11-18T07:00:00Z")};
        Clock clock = new Clock() {
            public java.time.ZoneId getZone() { return ZoneOffset.UTC; }
            public Clock withZone(java.time.ZoneId z) { return this; }
            public Instant instant() { return now[0]; }
        };
        FallbackAiClient ai = new FallbackAiClient(List.of(
            new FallbackAiClient.Named("gemini", gemini), new FallbackAiClient.Named("groq", groq)), clock);
        assertEquals("groq", ai.complete("s", HI, 100));
        assertEquals("groq", ai.complete("s", HI, 100));
        assertEquals(1, gemini.calls.get(), "đang nghỉ: không chờ Gemini lần nữa");
        now[0] = now[0].plus(FallbackAiClient.DOWN_COOLDOWN).plusSeconds(1);
        ai.complete("s", HI, 100);
        assertEquals(2, gemini.calls.get(), "hết thời gian nghỉ ngắn thì thử lại Gemini");
    }

    @Test
    void loi_thuong_khong_bat_nghi_va_het_noi_thi_nem_loi() {
        Fake gemini = new Fake(true, () -> { throw new AiClient.AiUnavailableException("500", null); });
        Fake groq = new Fake(true, () -> { throw new AiClient.AiUnavailableException("500", null); });
        FallbackAiClient ai = new FallbackAiClient(List.of(
            new FallbackAiClient.Named("gemini", gemini), new FallbackAiClient.Named("groq", groq)),
            Clock.systemUTC());
        assertThrows(AiClient.AiUnavailableException.class, () -> ai.complete("s", HI, 100));
        assertThrows(AiClient.AiUnavailableException.class, () -> ai.complete("s", HI, 100));
        assertEquals(2, gemini.calls.get(), "lỗi thường (không phải hết lượt): lần sau vẫn thử Gemini");
    }

    @Test
    void bo_noi_chua_co_key_va_khong_doi_noi_khi_da_phat_chu() {
        Fake missing = new Fake(false, () -> "không bao giờ");
        assertFalse(new FallbackAiClient(List.of(new FallbackAiClient.Named("x", missing)), Clock.systemUTC())
            .available());

        AiClient streamsThenFails = new Fake(true, () -> "") {
            @Override
            public String stream(String s, List<Message> m, int t, java.util.function.Consumer<String> onText) {
                onText.accept("một nửa");
                throw new AiClient.AiUnavailableException("đứt giữa chừng", null);
            }
        };
        Fake groq = new Fake(true, () -> "groq");
        FallbackAiClient ai = new FallbackAiClient(List.of(
            new FallbackAiClient.Named("gemini", streamsThenFails), new FallbackAiClient.Named("groq", groq)),
            Clock.systemUTC());
        List<String> parts = new ArrayList<>();
        assertThrows(AiClient.AiUnavailableException.class, () -> ai.stream("s", HI, 100, parts::add));
        assertEquals(List.of("một nửa"), parts);
        assertEquals(0, groq.calls.get(), "đã phát chữ rồi thì không gọi nơi khác (tránh lặp chữ)");
    }

    @Test
    void groq_dung_dinh_dang_chat_completions() {
        var body = GroqAiClient.request("openai/gpt-oss-120b", "hệ thống",
            List.of(AiClient.Message.user("a"), AiClient.Message.assistant("b"), AiClient.Message.user("c")), 300);
        assertEquals("system", body.path("messages").path(0).path("role").asString());
        assertEquals("assistant", body.path("messages").path(2).path("role").asString());
        assertEquals(300 + GroqAiClient.REASONING_HEADROOM, body.path("max_completion_tokens").asInt());
        assertEquals("low", body.path("reasoning_effort").asString());
        assertTrue(GroqAiClient.request("qwen/qwen3.8-27b", "s", HI, 300).path("reasoning_effort").isMissingNode());

        String json = JsonMapper.builder().build().writeValueAsString(java.util.Map.of("choices",
            List.of(java.util.Map.of("message", java.util.Map.of("role", "assistant", "content", " Chào bạn ")))));
        assertEquals("Chào bạn", GroqAiClient.parseText(json));
        assertThrows(AiClient.AiUnavailableException.class, () -> GroqAiClient.parseText("{\"choices\":[]}"));
    }
}
