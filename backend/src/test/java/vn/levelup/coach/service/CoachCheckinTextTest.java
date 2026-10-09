package vn.levelup.coach.service;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

import vn.levelup.training.dto.TodayCheckin;

class CoachCheckinTextTest {

    @Test
    void checkin_is_described_for_the_coach() {
        assertEquals("chưa check-in", CoachService.checkinText(null));
        assertTrue(CoachService.checkinText(new TodayCheckin("tired", "lt6"))
            .startsWith("mệt, ngủ dưới 6 tiếng (ưu tiên gợi ý tập nhẹ"));
        assertTrue(CoachService.checkinText(new TodayCheckin("normal", "lt6")).contains("tập nhẹ"));
        assertEquals("bình thường, ngủ 7-8 tiếng", CoachService.checkinText(new TodayCheckin("normal", "h7_8")));
        assertTrue(CoachService.checkinText(new TodayCheckin("energized", null)).startsWith("sung sức (có thể"));
    }
}
