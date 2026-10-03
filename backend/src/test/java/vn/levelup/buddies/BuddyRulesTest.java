package vn.levelup.buddies;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Random;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;

class BuddyRulesTest {

    private static BuddyRules.PlannedSession session(String status, String time) {
        return new BuddyRules.PlannedSession(status, time, "Buổi " + time);
    }

    @Test
    void code_has_six_unambiguous_characters() {
        Random random = new Random(42);
        for (int i = 0; i < 2000; i++) {
            String code = BuddyRules.newCode(random);
            assertEquals(6, code.length());
            assertTrue(code.matches("[A-HJ-NP-Z2-9]{6}"), code);
        }
        for (char c : "0O1I".toCharArray()) {
            assertEquals(-1, BuddyRules.CODE_ALPHABET.indexOf(c));
        }
    }

    @Test
    void code_typed_loosely_is_normalized() {
        assertEquals("ABC234", BuddyRules.normalizeCode(" abc-234 "));
        assertEquals("", BuddyRules.normalizeCode(null));
    }

    @Test
    void pair_key_is_the_same_in_both_orders() {
        ObjectId small = new ObjectId("000000000000000000000001");
        ObjectId large = new ObjectId("ffffffffffffffffffffff01");
        String expected = small.toHexString() + "_" + large.toHexString();
        assertEquals(expected, BuddyRules.pairKey(small, large));
        assertEquals(expected, BuddyRules.pairKey(large, small));
    }

    @Test
    void trained_today_is_done_even_without_plan() {
        assertEquals("done", BuddyRules.todayStatus(true, false, List.of()).status());
        assertEquals("done", BuddyRules.todayStatus(false, true, List.of(session("completed", "18:30"))).status());
    }

    @Test
    void planned_takes_earliest_time() {
        BuddyRules.TodayStatus s = BuddyRules.todayStatus(false, true,
            List.of(session("planned", "18:30"), session("planned", "06:00"), session("skipped", "05:00")));
        assertEquals("planned", s.status());
        assertEquals("06:00", s.scheduledTime());
        assertEquals("Buổi 06:00", s.title());
    }

    @Test
    void rest_when_plan_has_nothing_today_or_marks_rest() {
        assertEquals("rest", BuddyRules.todayStatus(false, true, List.of()).status());
        assertEquals("rest", BuddyRules.todayStatus(false, true, List.of(session("rest", null))).status());
    }

    @Test
    void none_without_plan_or_after_skipping() {
        assertEquals("none", BuddyRules.todayStatus(false, false, List.of()).status());
        assertEquals("none", BuddyRules.todayStatus(false, true, List.of(session("skipped", "18:30"))).status());
        assertNull(BuddyRules.todayStatus(false, false, List.of()).scheduledTime());
    }

    @Test
    void sharing_defaults_to_nothing() {
        assertEquals(BuddyRules.Sharing.NONE, BuddyRules.Sharing.from(null));
        assertEquals(BuddyRules.Sharing.NONE, BuddyRules.Sharing.from(new Document("weight", "yes")));
        BuddyTodayResponse.Shared all = new BuddyTodayResponse.Shared(65.5,
            new BuddyTodayResponse.Measurements("2026-10-01", 80.0, null, null, null), 1500);
        assertNull(BuddyRules.filter(BuddyRules.Sharing.NONE, all));
    }

    @Test
    void sharing_reveals_only_enabled_items() {
        BuddyTodayResponse.Shared all = new BuddyTodayResponse.Shared(65.5,
            new BuddyTodayResponse.Measurements("2026-10-01", 80.0, null, null, null), 1500);
        BuddyTodayResponse.Shared weightOnly = BuddyRules.filter(
            BuddyRules.Sharing.from(new Document("weight", true).append("meals", false)), all);
        assertEquals(65.5, weightOnly.weightKg());
        assertNull(weightOnly.measurements());
        assertNull(weightOnly.mealsKcalToday());

        BuddyTodayResponse.Shared meals = BuddyRules.filter(new BuddyRules.Sharing(false, false, true, true), all);
        assertNull(meals.weightKg());
        assertEquals(1500, meals.mealsKcalToday());
    }
}
