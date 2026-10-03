package vn.levelup.nutrition;

import static org.junit.jupiter.api.Assertions.assertEquals;
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
}
