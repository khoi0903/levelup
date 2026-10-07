package vn.levelup.coach.ai;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.util.List;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.node.ObjectNode;

class GeminiAiClientTest {

    @Test
    void text_request_maps_roles_and_system() {
        ObjectNode body = GeminiAiClient.textRequest("Bạn là coach", List.of(
            AiClient.Message.user("Chào"), AiClient.Message.assistant("Chào bạn"), AiClient.Message.user("Đau vai")),
            500);
        assertEquals("Bạn là coach", body.at("/systemInstruction/parts/0/text").asString());
        assertEquals("user", body.at("/contents/0/role").asString());
        assertEquals("model", body.at("/contents/1/role").asString());
        assertEquals("Đau vai", body.at("/contents/2/parts/0/text").asString());
        assertEquals(500 + GeminiAiClient.THINKING_HEADROOM,
            body.at("/generationConfig/maxOutputTokens").asInt());
    }

    @Test
    void image_request_sends_inline_base64_then_prompt() {
        ObjectNode body = GeminiAiClient.imageRequest("sys", "Món gì?", new byte[] {1, 2, 3}, "image/jpeg", 300);
        assertEquals("image/jpeg", body.at("/contents/0/parts/0/inlineData/mimeType").asString());
        assertEquals("AQID", body.at("/contents/0/parts/0/inlineData/data").asString());
        assertEquals("Món gì?", body.at("/contents/0/parts/1/text").asString());
    }

    @Test
    void parse_joins_text_parts_and_skips_thoughts() {
        String response = """
            {"candidates":[{"content":{"role":"model","parts":[
              {"text":"nghĩ...","thought":true},{"text":"{\\"reply\\":"},{"text":"\\"Ok\\"}"}]},
              "finishReason":"STOP"}]}""";
        assertEquals("{\"reply\":\"Ok\"}", GeminiAiClient.parseText(response));
    }

    @Test
    void blocked_or_empty_response_is_unavailable() {
        assertThrows(AiClient.AiUnavailableException.class,
            () -> GeminiAiClient.parseText("{\"promptFeedback\":{\"blockReason\":\"SAFETY\"}}"));
        assertThrows(AiClient.AiUnavailableException.class,
            () -> GeminiAiClient.parseText("{\"candidates\":[{\"finishReason\":\"MAX_TOKENS\",\"content\":{\"parts\":[]}}]}"));
    }

    @Test
    void no_key_means_unavailable_without_network() {
        GeminiAiClient client = new GeminiAiClient(" ", "gemini-2.5-flash", 5);
        assertFalse(client.available());
        assertThrows(AiClient.AiUnavailableException.class,
            () -> client.complete("s", List.of(AiClient.Message.user("x")), 10));
    }

    @Test
    void provider_choice() {
        assertEquals("gemini", AiConfig.choose("gemini", "sk-ant", null));
        assertEquals("claude", AiConfig.choose("auto", "sk-ant", "g"));
        assertEquals("gemini", AiConfig.choose("auto", null, "g"));
        assertEquals("gemini", AiConfig.choose(null, " ", "g"));
        assertEquals("claude", AiConfig.choose("auto", null, null));
    }

    @Test
    void stream_chunk_text_skips_thoughts_and_detects_block() {
        assertEquals("Chào bạn", GeminiAiClient.parseChunk("""
            {"candidates":[{"content":{"parts":[{"text":"nghĩ…","thought":true},{"text":"Chào bạn"}]}}]}"""));
        assertEquals("", GeminiAiClient.parseChunk("{\"candidates\":[{\"finishReason\":\"STOP\"}]}"));
        assertEquals("", GeminiAiClient.parseChunk(""));
        assertThrows(AiClient.AiUnavailableException.class,
            () -> GeminiAiClient.parseChunk("{\"promptFeedback\":{\"blockReason\":\"SAFETY\"}}"));
    }
}
