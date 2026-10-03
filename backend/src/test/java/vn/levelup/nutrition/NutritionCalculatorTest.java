package vn.levelup.nutrition;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;

import org.junit.jupiter.api.Test;

import vn.levelup.users.User;

class NutritionCalculatorTest {

    private static final LocalDate TODAY = LocalDate.parse("2026-10-05");

    @Test
    void namGiamMoTinhDungTheoMifflin() {
        // nam, 28 tuổi, 170 cm, 70 kg: BMR = 700 + 1062.5 - 140 + 5 = 1627.5; TDEE = 2237.8
        // giảm mỡ: trừ min(500, 20% TDEE = 447.6) -> 1790.2 -> làm tròn 1790
        User.NutritionTarget t = NutritionCalculator.compute("male", 1998, 170, 70, "lose_fat", TODAY);
        assertEquals(1790, t.kcal());
        assertEquals(112, t.proteinG());          // 1.6 g/kg
        assertEquals(50, t.fatG());               // 25% kcal / 9
        assertEquals("2026-10-05", t.effectiveFrom());
    }

    @Test
    void khongBaoGioDuoiMucSan() {
        User.NutritionTarget nu = NutritionCalculator.compute("female", 2000, 145, 38, "lose_fat", TODAY);
        assertEquals(1200, nu.kcal());
        User.NutritionTarget nam = NutritionCalculator.compute("male", 1960, 150, 40, "lose_fat", TODAY);
        assertEquals(1500, nam.kcal());
    }

    @Test
    void macroCongLaiXapXiTongCalo() {
        User.NutritionTarget t = NutritionCalculator.compute("female", 1995, 160, 55, "maintain", TODAY);
        int fromMacros = t.proteinG() * 4 + t.carbsG() * 4 + t.fatG() * 9;
        assertTrue(Math.abs(fromMacros - t.kcal()) <= 10, "chênh lệch " + (fromMacros - t.kcal()));
    }

    @Test
    void thieuNamSinhVaGioiTinhVanTinhDuoc() {
        User.NutritionTarget t = NutritionCalculator.compute(null, null, 165, 60, "get_healthier", TODAY);
        assertTrue(t.kcal() >= 1200);
    }
}
