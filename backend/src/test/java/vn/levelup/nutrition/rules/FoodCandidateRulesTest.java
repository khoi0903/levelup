package vn.levelup.nutrition.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import java.util.Arrays;
import java.util.List;

import org.junit.jupiter.api.Test;

class FoodCandidateRulesTest {

    @Test
    void goiYLaTrungViCacLanAiUocTinh() {
        List<RecognitionParser.Estimate> ai = List.of(new RecognitionParser.Estimate(60, 1, 12, 1),
            new RecognitionParser.Estimate(80, 2, 15, 1), new RecognitionParser.Estimate(800, 0, 0, 89));
        RecognitionParser.Estimate e = FoodCandidateRules.suggestPer100g(ai);
        assertEquals(80, e.kcal());          // một lần sai (800) không kéo lệch
        assertEquals(12.0, e.carbsG());
        assertEquals(70, FoodCandidateRules.suggestPer100g(ai.subList(0, 2)).kcal());
        assertNull(FoodCandidateRules.suggestPer100g(List.of()));
    }

    @Test
    void khauPhanHayGapBoQuaSoGamKhongHopLe() {
        assertEquals(450.0, FoodCandidateRules.typicalGrams(Arrays.asList(400.0, 500.0, null, 0.0)));
        assertNull(FoodCandidateRules.typicalGrams(List.of()));
    }
}
