package vn.levelup.engagement.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.time.LocalDateTime;

import org.junit.jupiter.api.Test;

class JobRulesTest {

    @Test
    void day_close_waits_until_five_past_midnight() {
        assertEquals(LocalDate.of(2026, 10, 2), JobRules.dayToClose(LocalDateTime.of(2026, 10, 4, 0, 4)));
        assertEquals(LocalDate.of(2026, 10, 3), JobRules.dayToClose(LocalDateTime.of(2026, 10, 4, 0, 5)));
        assertEquals(LocalDate.of(2026, 10, 3), JobRules.dayToClose(LocalDateTime.of(2026, 10, 4, 23, 59)));
    }

    @Test
    void week_close_on_sunday_from_seven_pm() {
        assertFalse(JobRules.weekCloseDue(LocalDateTime.of(2026, 10, 4, 18, 59)));   // Chủ nhật
        assertTrue(JobRules.weekCloseDue(LocalDateTime.of(2026, 10, 4, 19, 0)));
        assertFalse(JobRules.weekCloseDue(LocalDateTime.of(2026, 10, 3, 20, 0)));    // Thứ Bảy
    }
}
