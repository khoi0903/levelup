package vn.levelup.motivation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Set;

import org.junit.jupiter.api.Test;

/** Bậc nhắc quay lại (F3) và quyết định chốt tuần (F4). */
class MotivationRulesTest {

    @Test
    void stage_moves_up_by_missed_sessions() {
        assertEquals("active", ReengagementRules.next("active", 0, 1));
        assertEquals("missed_1", ReengagementRules.next("active", 1, 2));
        assertEquals("missed_2", ReengagementRules.next("missed_1", 2, 3));
        assertEquals("missed_2", ReengagementRules.next(null, 3, 3));
    }

    @Test
    void stage_moves_up_by_days_and_never_down() {
        assertEquals("lapsed_7", ReengagementRules.next("missed_2", 2, 7));
        assertEquals("lapsed_14", ReengagementRules.next("lapsed_7", 0, 14));
        assertEquals("dormant", ReengagementRules.next("lapsed_14", 0, 30));
        assertEquals("lapsed_14", ReengagementRules.next("lapsed_14", 0, 3));   // chốt ngày không hạ bậc
        assertEquals("missed_1", ReengagementRules.next("bad-stage", 1, 0));
    }

    @Test
    void lapsed_messages_are_capped() {
        assertTrue(ReengagementRules.lapsedMessageDue("lapsed_7", 0));
        assertFalse(ReengagementRules.lapsedMessageDue("lapsed_7", 1));
        assertTrue(ReengagementRules.lapsedMessageDue("lapsed_14", 1));
        assertFalse(ReengagementRules.lapsedMessageDue("lapsed_14", 2));
        assertFalse(ReengagementRules.lapsedMessageDue("missed_2", 0));
        assertFalse(ReengagementRules.lapsedMessageDue("dormant", 0));
    }

    @Test
    void achieved_week_adds_streak_and_badges() {
        var d = WeekCloseRules.decide("in_progress", 3, 3, 0, 1, 1, 1, Set.of());
        assertEquals("achieved", d.status());
        assertEquals(2, d.currentWeeks());
        assertEquals(2, d.bestWeeks());
        assertNull(d.freezeEvent());
        assertEquals(List.of("streak_2"), d.newAchievements());

        var owned = WeekCloseRules.decide("achieved", 1, 3, 0, 1, 5, 1, Set.of("streak_2"));
        assertEquals(List.of(), owned.newAchievements());
        assertEquals(5, owned.bestWeeks());
    }

    @Test
    void every_fourth_achieved_week_earns_a_freeze_up_to_two() {
        var fourth = WeekCloseRules.decide("in_progress", 3, 3, 0, 3, 3, 3, Set.of("streak_2"));
        assertEquals(1, fourth.freezesAvailable());
        assertEquals("earned", fourth.freezeEvent());
        assertEquals(List.of("streak_4"), fourth.newAchievements());

        var full = WeekCloseRules.decide("in_progress", 3, 3, 2, 7, 7, 7, Set.of("streak_2", "streak_4"));
        assertEquals(2, full.freezesAvailable());
        assertNull(full.freezeEvent());
        assertEquals(List.of("streak_8"), full.newAchievements());
    }

    @Test
    void missed_week_uses_freeze_or_resets() {
        var frozen = WeekCloseRules.decide("in_progress", 1, 3, 1, 4, 4, 4, Set.of("streak_2", "streak_4"));
        assertEquals("frozen", frozen.status());
        assertEquals("used", frozen.freezeEvent());
        assertEquals(0, frozen.freezesAvailable());
        assertEquals(4, frozen.currentWeeks());
        assertEquals(List.of("streak_freeze_1"), frozen.newAchievements());

        var missed = WeekCloseRules.decide("in_progress", 0, 3, 0, 4, 4, 4, Set.of());
        assertEquals("missed", missed.status());
        assertEquals(0, missed.currentWeeks());
        assertEquals(4, missed.bestWeeks());
        assertEquals(List.of(), missed.newAchievements());
    }
}
