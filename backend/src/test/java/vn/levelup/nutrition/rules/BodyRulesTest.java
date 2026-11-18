package vn.levelup.nutrition.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;

import org.junit.jupiter.api.Test;

class BodyRulesTest {

    @Test
    void bmiLamTronMotChuSoVaNullKhiThieuSo() {
        assertEquals(24.2, BodyRules.bmi(170.0, 70.0));      // 70 / 1.7² = 24.22
        assertEquals(18.4, BodyRules.bmi(165.0, 50.0));      // 18.37
        assertNull(BodyRules.bmi(null, 70.0));
        assertNull(BodyRules.bmi(170.0, null));
        assertNull(BodyRules.bmi(0.0, 70.0));
    }

    @Test
    void phanLoaiTheoNguongChauA() {
        assertEquals("underweight", BodyRules.bmiCategory(18.4));
        assertEquals("normal", BodyRules.bmiCategory(18.5));
        assertEquals("normal", BodyRules.bmiCategory(22.9));
        assertEquals("overweight", BodyRules.bmiCategory(23.0));
        assertEquals("overweight", BodyRules.bmiCategory(24.9));
        assertEquals("obese", BodyRules.bmiCategory(25.0));
        assertNull(BodyRules.bmiCategory(null));
    }

    @Test
    void uocTinhMoTheoDeurenberg() {
        // nam 30 tuổi BMI 24.2: 29.04 + 6.9 − 10.8 − 5.4 = 19.74 → 20
        assertEquals(20, BodyRules.estimateBodyFatPct(24.2, 30, "male"));
        // nữ và "other" không trừ 10.8: 30.54 → 31
        assertEquals(31, BodyRules.estimateBodyFatPct(24.2, 30, "female"));
        assertEquals(31, BodyRules.estimateBodyFatPct(24.2, 30, "other"));
        assertEquals(31, BodyRules.estimateBodyFatPct(24.2, 30, null));
        assertNull(BodyRules.estimateBodyFatPct(null, 30, "male"));
    }

    @Test
    void uocTinhLuonTrongKhoang5Den50() {
        assertEquals(5, BodyRules.estimateBodyFatPct(14.0, 14, "male"));      // 16.8 + 3.22 − 16.2 = 3.8
        assertEquals(50, BodyRules.estimateBodyFatPct(45.0, 60, "female"));   // 54 + 13.8 − 5.4 = 62.4
    }

    @Test
    void uuTienSoDoRoiHoSoRoiMoiUocTinh() {
        BodyRules.BodyFat measured = BodyRules.bodyFat(18.6, 25, 24.2, 30, "male");
        assertEquals(19, measured.pct());
        assertFalse(measured.estimated());

        BodyRules.BodyFat chosen = BodyRules.bodyFat(null, 25, 24.2, 30, "male");
        assertEquals(25, chosen.pct());
        assertFalse(chosen.estimated());

        BodyRules.BodyFat estimated = BodyRules.bodyFat(null, null, 24.2, 30, "male");
        assertEquals(20, estimated.pct());
        assertTrue(estimated.estimated());

        BodyRules.BodyFat unknown = BodyRules.bodyFat(null, null, null, 30, "male");
        assertNull(unknown.pct());
        assertFalse(unknown.estimated());
    }

    @Test
    void bmrVaTdeeDungChungCongThucVoiMucTieuCalo() {
        LocalDate today = LocalDate.parse("2026-10-05");
        // nam, 28 tuổi, 170 cm, 70 kg: BMR 1627.5, TDEE 2237.8 (giống NutritionCalculatorTest)
        double bmr = NutritionCalculator.bmr("male", NutritionCalculator.age(1998, today), 170, 70);
        assertEquals(1627.5, bmr, 0.001);
        assertEquals(2237.8, NutritionCalculator.tdee(bmr), 0.05);
        assertEquals(25, NutritionCalculator.age(null, today));
        assertEquals(14, NutritionCalculator.age(2020, today));
    }
}
