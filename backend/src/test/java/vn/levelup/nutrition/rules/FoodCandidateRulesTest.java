package vn.levelup.nutrition.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.util.List;

import org.junit.jupiter.api.Test;

class FoodCandidateRulesTest {

    @Test
    void uuTienSoNguoiDungDaLuuVaDungTrungVi() {
        List<FoodCandidateRules.Saved> saved = List.of(
            new FoodCandidateRules.Saved(500.0, 350, 5, 60, 10),
            new FoodCandidateRules.Saved(400.0, 320, 4, 56, 8),
            new FoodCandidateRules.Saved(500.0, 4000, 0, 0, 0),   // nhập sai: 800 kcal/100 g vẫn trong giới hạn
            new FoodCandidateRules.Saved(null, 300, 0, 0, 0));   // không có số gam: bỏ qua khi tính 100 g
        List<RecognitionParser.Estimate> ai = List.of(new RecognitionParser.Estimate(200, 1, 40, 4));
        RecognitionParser.Estimate e = FoodCandidateRules.suggestPer100g(saved, ai);
        assertEquals(80, e.kcal());          // trung vị của 70, 80, 800
        assertEquals(500.0, FoodCandidateRules.typicalGrams(saved));
    }

    @Test
    void khongCoSoNguoiDungThiLayAi() {
        List<RecognitionParser.Estimate> ai = List.of(new RecognitionParser.Estimate(60, 1, 12, 1),
            new RecognitionParser.Estimate(80, 2, 15, 1));
        RecognitionParser.Estimate e = FoodCandidateRules.suggestPer100g(
            List.of(new FoodCandidateRules.Saved(null, 300, 0, 0, 0)), ai);
        assertEquals(70, e.kcal());
        assertEquals(13.5, e.carbsG());
        assertNull(FoodCandidateRules.suggestPer100g(List.of(), List.of()));
        assertNull(FoodCandidateRules.typicalGrams(List.of()));
    }
}
