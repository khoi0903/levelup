package vn.levelup.training.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.util.Optional;
import java.util.Set;

import org.junit.jupiter.api.Test;
import vn.levelup.training.dto.MeasurementDtos;

class MeasurementRulesTest {

    @Test
    void canItNhatMotChiSo() {
        assertFalse(MeasurementRules.hasAnyValue(
            new MeasurementDtos.MeasurementRequest(null, null, null, null, null, null, "2026-10-01")));
        assertTrue(MeasurementRules.hasAnyValue(
            new MeasurementDtos.MeasurementRequest(null, null, null, null, 30.0, null, null)));
    }

    @Test
    void ngayDoHopLe() {
        LocalDate today = LocalDate.parse("2026-10-05");
        assertTrue(MeasurementRules.validDate(today, today));
        assertTrue(MeasurementRules.validDate(today.minusDays(365), today));
        assertFalse(MeasurementRules.validDate(today.plusDays(1), today));
        assertFalse(MeasurementRules.validDate(today.minusDays(366), today));
    }

    @Test
    void huyHieuGiamVongEo() {
        assertEquals(Optional.of("body_waist_cm_1"), MeasurementRules.waistAchievement(80.0, 79.0, Set.of()));
        assertEquals(Optional.of("body_waist_cm_1"), MeasurementRules.waistAchievement(80.3, 79.3, Set.of()));
        assertTrue(MeasurementRules.waistAchievement(80.0, 79.1, Set.of()).isEmpty());
        assertTrue(MeasurementRules.waistAchievement(80.0, 78.0, Set.of("body_waist_cm_1")).isEmpty());
        assertTrue(MeasurementRules.waistAchievement(null, 78.0, Set.of()).isEmpty());
    }
}
