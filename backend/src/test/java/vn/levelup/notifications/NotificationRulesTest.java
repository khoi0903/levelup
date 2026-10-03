package vn.levelup.notifications;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import java.time.LocalTime;
import java.time.ZoneId;

import org.junit.jupiter.api.Test;

class NotificationRulesTest {

    private static final LocalTime START = LocalTime.of(22, 0);
    private static final LocalTime END = LocalTime.of(7, 0);
    private static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");

    @Test
    void quiet_hours_cross_midnight() {
        assertTrue(NotificationRules.isQuiet(LocalTime.of(22, 0), START, END));
        assertTrue(NotificationRules.isQuiet(LocalTime.of(23, 59), START, END));
        assertTrue(NotificationRules.isQuiet(LocalTime.of(3, 0), START, END));
        assertFalse(NotificationRules.isQuiet(LocalTime.of(7, 0), START, END));
        assertFalse(NotificationRules.isQuiet(LocalTime.of(21, 59), START, END));
    }

    @Test
    void quiet_hours_same_day_and_disabled() {
        assertTrue(NotificationRules.isQuiet(LocalTime.of(13, 0), LocalTime.of(12, 0), LocalTime.of(14, 0)));
        assertFalse(NotificationRules.isQuiet(LocalTime.of(14, 0), LocalTime.of(12, 0), LocalTime.of(14, 0)));
        assertFalse(NotificationRules.isQuiet(LocalTime.of(3, 0), LocalTime.MIDNIGHT, LocalTime.MIDNIGHT));
    }

    @Test
    void next_quiet_end_is_today_or_tomorrow() {
        // 23:30 giờ VN ngày 3/10 → 07:00 ngày 4/10
        Instant lateEvening = Instant.parse("2026-10-03T16:30:00Z");
        assertEquals(Instant.parse("2026-10-04T00:00:00Z"), NotificationRules.nextQuietEnd(lateEvening, VN, END));
        // 05:00 giờ VN → 07:00 cùng ngày
        Instant earlyMorning = Instant.parse("2026-10-03T22:00:00Z");
        assertEquals(Instant.parse("2026-10-04T00:00:00Z"), NotificationRules.nextQuietEnd(earlyMorning, VN, END));
    }

    @Test
    void settings_defaults() {
        assertEquals(START, NotificationRules.time(null, START));
        assertEquals(START, NotificationRules.time("25:99", START));
        assertEquals(LocalTime.of(21, 30), NotificationRules.time("21:30", START));
        assertEquals(2, NotificationRules.maxPerDay(null));
        assertEquals(3, NotificationRules.maxPerDay(3.0));
        assertEquals(0, NotificationRules.maxPerDay(-1));
    }

    @Test
    void gate_order_follows_flowchart() {
        assertEquals(NotificationRules.Gate.STORE_ONLY, NotificationRules.gate(false, 2, true));
        assertEquals(NotificationRules.Gate.STORE_ONLY, NotificationRules.gate(true, 0, false));
        assertEquals(NotificationRules.Gate.QUIET_HOURS, NotificationRules.gate(true, 1, true));
        assertEquals(NotificationRules.Gate.TRY_SEND, NotificationRules.gate(true, 1, false));
    }
}
