package vn.levelup.nutrition.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;

import org.junit.jupiter.api.Test;

class RecognitionParserTest {

    @Test
    void docJsonHopLe() {
        String raw = """
            ```json
            {"dishes":[{"name":"Beef pho","nameVi":"Phở bò","ingredients":["bánh phở","thịt bò",""],
              "portionGrams":520.4,"confidence":0.86}]}
            ```""";
        List<RecognitionParser.Dish> dishes = RecognitionParser.parse(raw);
        assertEquals(1, dishes.size());
        RecognitionParser.Dish d = dishes.get(0);
        assertEquals("Phở bò", d.nameVi());
        assertEquals(520, d.portionGrams());
        assertEquals(0.86, d.confidence());
        assertEquals(List.of("bánh phở", "thịt bò"), d.ingredients());
        assertTrue(RecognitionParser.parse("{\"dishes\":[]}").isEmpty());
    }

    @Test
    void thieuTenThiDungTenConLai() {
        RecognitionParser.Dish d = RecognitionParser.parse(
            "{\"dishes\":[{\"nameVi\":\"Bánh mì\",\"portionGrams\":200,\"confidence\":1}]}").get(0);
        assertEquals("Bánh mì", d.name());
        assertEquals(List.of(), d.ingredients());
    }

    @Test
    void tuChoiKetQuaSai() {
        for (String raw : new String[] {
            null, "Xin lỗi, tôi không thấy món ăn", "{\"dishes\":", "{\"items\":[]}", "{\"dishes\":{}}",
            "{\"dishes\":[{\"portionGrams\":200,\"confidence\":0.5}]}",
            "{\"dishes\":[{\"name\":\"x\",\"portionGrams\":0,\"confidence\":0.5}]}",
            "{\"dishes\":[{\"name\":\"x\",\"portionGrams\":\"300\",\"confidence\":0.5}]}",
            "{\"dishes\":[{\"name\":\"x\",\"portionGrams\":300,\"confidence\":1.5}]}",
            "{\"dishes\":[{\"name\":\"x\",\"portionGrams\":300,\"confidence\":0.5,\"ingredients\":\"bò\"}]}"}) {
            assertThrows(RecognitionParser.InvalidOutputException.class, () -> RecognitionParser.parse(raw), raw);
        }
    }

    @Test
    void docSoUocTinhCho100g() {
        RecognitionParser.Dish d = RecognitionParser.parse("""
            {"dishes":[{"nameVi":"Trà dâu kem cheese","portionGrams":500,"confidence":0.8,
              "per100g":{"kcal":75,"proteinG":1.2,"carbsG":12,"fatG":2.5}}]}""").get(0);
        assertEquals(new RecognitionParser.Estimate(75, 1.2, 12, 2.5), d.per100g());
        NutritionRules.Portion p = NutritionRules.estimatePortion(d.per100g(), d.portionGrams());
        assertEquals(375, p.kcal());
        assertEquals(281, p.kcalMin());
        assertEquals(469, p.kcalMax());
        assertEquals(60.0, p.carbsG());
    }

    @Test
    void soUocTinhVoLyThiBoQuaNhungVanGiuMon() {
        for (String per100g : new String[] {
            "null", "\"75\"", "{\"kcal\":75}", "{\"kcal\":950,\"proteinG\":0,\"carbsG\":0,\"fatG\":100}",
            "{\"kcal\":-1,\"proteinG\":0,\"carbsG\":0,\"fatG\":0}",
            "{\"kcal\":75,\"proteinG\":-1,\"carbsG\":12,\"fatG\":2.5}",
            "{\"kcal\":75,\"proteinG\":60,\"carbsG\":60,\"fatG\":0}",
            "{\"kcal\":300,\"proteinG\":1,\"carbsG\":12,\"fatG\":2.5}"}) {
            RecognitionParser.Dish d = RecognitionParser.parse(
                "{\"dishes\":[{\"nameVi\":\"Món lạ\",\"portionGrams\":300,\"confidence\":0.5,\"per100g\":"
                    + per100g + "}]}").get(0);
            assertNull(d.per100g(), per100g);
        }
        assertNull(RecognitionParser.parse(
            "{\"dishes\":[{\"nameVi\":\"Món lạ\",\"portionGrams\":300,\"confidence\":0.5}]}").get(0).per100g());
    }

    @Test
    void nuocLocTraKhongDuong0KcalVanCoUocTinh() {
        RecognitionParser.Dish d = RecognitionParser.parse("""
            {"dishes":[{"nameVi":"Trà đá","portionGrams":300,"confidence":0.9,
              "per100g":{"kcal":0.4,"proteinG":0,"carbsG":0.1,"fatG":0}}]}""").get(0);
        assertEquals(0, d.per100g().kcal());
        assertEquals(0, NutritionRules.estimatePortion(d.per100g(), 300).kcal());
    }
}
