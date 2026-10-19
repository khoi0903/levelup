package vn.levelup.coach.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class VoiceLineRulesTest {

    @Test
    void cauMauTheoPhongCachVaLuonNhacVayTay() {
        for (String style : new String[] {"strict", "supportive", "funny", null}) {
            assertTrue(VoiceLineRules.template("idle_prompt", style).contains("Vẫy tay")
                || VoiceLineRules.template("idle_prompt", style).contains("vẫy tay"), String.valueOf(style));
            assertTrue(!VoiceLineRules.template("skipped", style).isBlank());
        }
    }

    @Test
    void lamSachCauAi() {
        assertEquals("Squat hơi khó hôm nay à? Vẫy tay nếu muốn đổi bài nhé.",
            VoiceLineRules.clean("\"Squat hơi **khó** hôm nay à?\n Vẫy tay nếu muốn đổi bài nhé.\"", "idle_prompt"));
        // Thiếu hướng dẫn vẫy tay thì thêm vào
        assertEquals("Nghỉ chút rồi làm tiếp nhé. Vẫy tay nếu muốn bỏ qua.",
            VoiceLineRules.clean("Nghỉ chút rồi làm tiếp nhé. 💪", "idle_prompt"));
        assertEquals("Qua bài mới nào.", VoiceLineRules.clean("Qua bài mới nào.", "skipped"));
        assertNull(VoiceLineRules.clean("   ", "skipped"));
        assertNull(VoiceLineRules.clean(null, "skipped"));
        assertNull(VoiceLineRules.clean("a".repeat(200), "skipped"));
    }
}
