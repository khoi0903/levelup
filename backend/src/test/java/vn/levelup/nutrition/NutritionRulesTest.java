package vn.levelup.nutrition;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;

import org.junit.jupiter.api.Test;

import vn.levelup.users.User;

class NutritionRulesTest {

    static Food food(String id, String name, String category, double grams, double kcal, double protein) {
        return new Food(id, name, VietText.normalize(name), List.of(), category, "1 phần", grams, kcal, protein,
            10, 5);
    }

    @Test
    void khoangKcalTheoKhauPhan() {
        Food pho = new Food("1", "Phở bò tái", "pho bo tai", List.of(), "bun_pho_mi", "1 tô", 550, 430, 28, 60, 10);
        NutritionRules.Portion same = NutritionRules.portion(pho, 550);
        assertEquals(430, same.kcal());
        assertEquals(366, same.kcalMin());     // 430 * 0.85 = 365.5
        assertEquals(494, same.kcalMax());     // 430 * 1.15 = 494.4999... (số thực)
        NutritionRules.Portion small = NutritionRules.portion(pho, 275);
        assertEquals(215, small.kcal());
        assertEquals(14.0, small.proteinG());
        assertEquals(30.0, small.carbsG());
        assertEquals(5.0, small.fatG());
    }

    @Test
    void mucTieuApMucSan() {
        LocalDate today = LocalDate.parse("2026-10-05");
        List<User.NutritionTarget> history = List.of(
            new User.NutritionTarget("2026-09-01", 1800, 100, 200, 50, 2000, "m"),
            new User.NutritionTarget("2026-10-01", 1400, 110, 150, 40, 2250, "m"),
            new User.NutritionTarget("2026-10-10", 1700, 120, 180, 45, 2500, "m"));   // chưa tới ngày
        NutritionRules.Target female = NutritionRules.effectiveTarget(history, today, "female");
        assertEquals(1400, female.kcal());
        assertEquals(110, female.proteinG());
        assertEquals(2250, female.waterMl());
        assertEquals(1500, NutritionRules.effectiveTarget(history, today, "male").kcal());

        List<User.NutritionTarget> tooLow = List.of(new User.NutritionTarget("2026-10-01", 900, 80, 90, 30, null, "m"));
        assertEquals(1200, NutritionRules.effectiveTarget(tooLow, today, null).kcal());
        assertEquals(0, NutritionRules.effectiveTarget(tooLow, today, null).waterMl());
        // chỉ có mục tiêu tương lai: lấy phần tử cuối
        assertEquals(1700, NutritionRules.effectiveTarget(history.subList(2, 3), today, "female").kcal());
        assertNull(NutritionRules.effectiveTarget(List.of(), today, "male"));
    }

    @Test
    void goiYDamChiSau15GioVaThieuHon30g() {
        assertFalse(NutritionRules.shouldSuggestProtein(LocalTime.of(14, 59), 80));
        assertTrue(NutritionRules.shouldSuggestProtein(LocalTime.of(15, 0), 30.5));
        assertFalse(NutritionRules.shouldSuggestProtein(LocalTime.of(19, 0), 30));
    }

    @Test
    void chonMonNhieuDamVuaCalo() {
        List<Food> foods = List.of(
            food("a", "Gà kho gừng", "com", 150, 260, 27),
            food("b", "Canh chua cá", "mon_canh", 300, 150, 18),
            food("c", "Cá basa kho tộ", "com", 150, 240, 23),
            food("d", "Cơm tấm sườn bì chả", "com", 450, 750, 35),
            food("e", "Trà sữa", "do_uong", 300, 350, 3));
        // ưu tiên đạm/kcal: canh chua (0.12) > gà kho (0.104) > cá kho (0.096); món 2 khác nhóm với món 1
        List<Food> picked = NutritionRules.proteinFoods(foods, 500, 45);
        assertEquals(List.of("b", "a"), picked.stream().map(Food::id).toList());
        // còn ít calo: chỉ một món vừa
        assertEquals(List.of("b"), NutritionRules.proteinFoods(foods, 200, 45).stream().map(Food::id).toList());
        // hết calo: không gợi ý
        assertTrue(NutritionRules.proteinFoods(foods, 100, 45).isEmpty());
        // món đầu đã đủ đạm: một món
        assertEquals(1, NutritionRules.proteinFoods(foods, 900, 15).size());

        String msg = NutritionRules.suggestionMessage(44.6, picked);
        assertEquals("Hôm nay bạn còn thiếu khoảng 45 g đạm. Bữa tới thử Canh chua cá (18 g đạm, 150 kcal)"
            + " và Gà kho gừng (27 g đạm, 260 kcal) nhé.", msg);
    }
}
