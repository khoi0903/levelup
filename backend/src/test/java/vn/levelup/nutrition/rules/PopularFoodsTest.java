package vn.levelup.nutrition.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import vn.levelup.nutrition.model.Food;

class PopularFoodsTest {

    private static Food food(String id, String name) {
        return new Food(id, name, name, List.of(), "x", "1 phần", 100, 100, 5, 10, 3);
    }

    @Test
    void monPhoBienDeuCoTrongKhoVaKhongTrung() throws Exception {
        // surefire chạy trong backend/, kho món nằm ở mongo/seed
        JsonNode seed = JsonMapper.builder().build()
            .readTree(Files.readString(Path.of("..", "mongo", "seed", "foods.json")));
        Set<String> names = new HashSet<>();
        seed.forEach(f -> names.add(f.get("nameVi").stringValue()));
        for (String meal : List.of("breakfast", "lunch", "dinner", "snack")) {
            List<String> curated = PopularFoods.curated(meal);
            assertEquals(PopularFoods.MAX_LIMIT, curated.size(), meal);
            assertEquals(curated.size(), new HashSet<>(curated).size(), meal + " có món trùng");
            for (String name : curated) {
                assertTrue(names.contains(name), meal + ": không có trong kho: " + name);
            }
        }
    }

    @Test
    void bua() {
        assertTrue(PopularFoods.validMeal("snack"));
        assertFalse(PopularFoods.validMeal("brunch"));
        assertFalse(PopularFoods.validMeal(null));
        assertEquals(1, PopularFoods.clampLimit(0));
        assertEquals(20, PopularFoods.clampLimit(99));
        assertEquals(8, PopularFoods.clampLimit(8));
    }

    @Test
    void xepTheoSoLanGhiBangNhauThiMoiHonTruoc() {
        assertEquals(List.of("b", "c", "a"), PopularFoods.rank(List.of("c", "b", "a", "b")));
        assertEquals(List.of(), PopularFoods.rank(List.of()));
    }

    @Test
    void monCuaNguoiDungTruocRoiToiMonPhoBienKhongTrung() {
        List<Food> catalog = new ArrayList<>();
        catalog.add(food("1", "Bánh flan"));
        catalog.add(food("2", "Phở bò tái"));
        catalog.add(food("3", "Bánh mì thịt"));
        catalog.add(food("4", "Bánh cuốn"));

        // "9" không còn trong kho: bỏ qua; "Phở bò tái" đã có ở phần của người dùng: không lặp lại
        List<Food> out = PopularFoods.merge(List.of("1", "9", "2"), "breakfast", catalog, 8);
        assertEquals(List.of("Bánh flan", "Phở bò tái", "Bánh mì thịt", "Bánh cuốn"),
            out.stream().map(Food::nameVi).toList());

        assertEquals(List.of("Bánh flan", "Phở bò tái"),
            PopularFoods.merge(List.of("1", "2"), "breakfast", catalog, 2).stream().map(Food::nameVi).toList());
        assertEquals(List.of("Phở bò tái", "Bánh mì thịt", "Bánh cuốn"),
            PopularFoods.merge(List.of(), "breakfast", catalog, 8).stream().map(Food::nameVi).toList());
    }

    @Test
    void chuanHoaCauVaCauHoiGuiAi() {
        assertEquals("2 bát phở bò", MealTextRules.normalize("  2 Bát \n phở   bò "));
        assertEquals("", MealTextRules.normalize("   "));
        assertEquals("", MealTextRules.normalize(null));
        // giữ dấu: "bò" khác "bơ"
        assertFalse(MealTextRules.normalize("bánh mì bò").equals(MealTextRules.normalize("bánh mì bơ")));
        String prompt = MealTextRules.prompt(" 1 ly trà đá ", "lunch");
        assertTrue(prompt.contains("bữa trưa"));
        assertTrue(prompt.contains("1 ly trà đá"));
    }
}
