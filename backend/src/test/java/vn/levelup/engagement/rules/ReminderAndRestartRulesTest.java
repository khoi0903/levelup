package vn.levelup.engagement.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

import org.bson.types.ObjectId;
import org.junit.jupiter.api.Test;
import vn.levelup.training.model.TrainingPlan;


class ReminderAndRestartRulesTest {

    @Test
    void checkin_window_three_hours_from_setting() {
        LocalTime at = LocalTime.of(7, 30);
        assertFalse(ReminderRules.checkinDue(LocalTime.of(7, 29), at));
        assertTrue(ReminderRules.checkinDue(LocalTime.of(7, 30), at));
        assertTrue(ReminderRules.checkinDue(LocalTime.of(10, 29), at));
        assertFalse(ReminderRules.checkinDue(LocalTime.of(10, 30), at));
        // cửa sổ vắt qua nửa đêm: 22:30 → 01:30
        assertTrue(ReminderRules.checkinDue(LocalTime.of(23, 0), LocalTime.of(22, 30)));
    }

    @Test
    void bad_time_falls_back_to_default() {
        assertEquals(ReminderRules.DEFAULT_CHECKIN, ReminderRules.time("7h30", ReminderRules.DEFAULT_CHECKIN));
        assertEquals(LocalTime.of(6, 0), ReminderRules.time("06:00", ReminderRules.DEFAULT_CHECKIN));
    }

    @Test
    void pre_workout_only_before_session_start() {
        LocalDateTime session = LocalDateTime.of(2026, 10, 5, 18, 30);
        assertFalse(ReminderRules.preWorkoutDue(session.minusMinutes(61), session, 60));
        assertTrue(ReminderRules.preWorkoutDue(session.minusMinutes(60), session, 60));
        assertTrue(ReminderRules.preWorkoutDue(session.minusMinutes(1), session, 60));
        assertFalse(ReminderRules.preWorkoutDue(session, session, 60));
    }

    @Test
    void water_due_by_slot_and_share_of_target() {
        assertEquals("noon", ReminderRules.waterDue(LocalTime.of(11, 0), 0, 2000).key());
        assertEquals(null, ReminderRules.waterDue(LocalTime.of(12, 0), 800, 2000));       // đủ 40%
        assertEquals("afternoon", ReminderRules.waterDue(LocalTime.of(17, 59), 1000, 2000).key());
        assertEquals(null, ReminderRules.waterDue(LocalTime.of(18, 0), 0, 2000));         // hết khung giờ
        assertEquals(null, ReminderRules.waterDue(LocalTime.of(14, 0), 0, 2000));
        assertEquals(null, ReminderRules.waterDue(LocalTime.of(11, 30), 0, 0));           // chưa có mục tiêu
    }

    @Test
    void lighten_caps_minutes_and_drops_one_set() {
        TrainingPlan.Session s = new TrainingPlan.Session(new ObjectId(), "2026-10-05", "18:30", "Toàn thân", 20,
            "normal", "planned", List.of(new TrainingPlan.Item(new ObjectId(), 3, 12, null, 45),
                new TrainingPlan.Item(new ObjectId(), 1, null, 30, 30)));
        TrainingPlan.Session light = RestartRules.lighten(s, 10, "restart_lapsed");
        assertEquals("light", light.variant());
        assertEquals(10, light.durationMin());
        assertEquals(2, light.items().get(0).targetSets());
        assertEquals(1, light.items().get(1).targetSets());   // không xuống 0
        assertEquals("restart_lapsed", light.adjustedReason());
        assertEquals(8, RestartRules.lighten(new TrainingPlan.Session(null, "2026-10-05", null, "t", 8, "normal",
            "planned", List.of()), 10, "r").durationMin());
    }
}
