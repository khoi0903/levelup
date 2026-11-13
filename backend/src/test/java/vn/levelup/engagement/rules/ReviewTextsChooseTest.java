package vn.levelup.engagement.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;

import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class ReviewTextsChooseTest {

    private static ReviewTexts.Facts facts(int done) {
        return new ReviewTexts.Facts("An", "supportive", done, 3, done * 10, null, "decrease", List.of(), null,
            0, null, 3, 10);
    }

    @Test
    void tuanKhongBuoiBoCauChienThangCuaAi() {
        var ai = new ReviewTexts.Texts("Bạn đã nghỉ ngơi trọn vẹn", "Tập 1 buổi ngắn", "Tuần sau 3 buổi");
        var t = ReviewTexts.choose(facts(0), Optional.of(ai));
        assertNotEquals(ai.win(), t.win());
        assertEquals(ReviewTexts.fallback(facts(0)).win(), t.win());
        assertEquals("Tập 1 buổi ngắn", t.improve());
        assertEquals("Tuần sau 3 buổi", t.nextWeekSummary());
    }

    @Test
    void tuanCoBuoiGiuNguyenCuaAi() {
        var ai = new ReviewTexts.Texts("2 buổi đều đặn", "Thêm giãn cơ", "Tuần sau 3 buổi");
        assertEquals(ai, ReviewTexts.choose(facts(2), Optional.of(ai)));
    }

    @Test
    void khongCoAiDungCauMau() {
        assertEquals(ReviewTexts.fallback(facts(1)), ReviewTexts.choose(facts(1), Optional.empty()));
    }
}
