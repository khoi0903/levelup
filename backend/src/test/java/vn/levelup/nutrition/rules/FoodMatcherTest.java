package vn.levelup.nutrition.rules;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;

import org.junit.jupiter.api.Test;
import vn.levelup.nutrition.model.Food;

class FoodMatcherTest {

    static Food food(String id, String nameVi, String searchName, List<String> aliases) {
        return new Food(id, nameVi, searchName, aliases, "com", "1 phần", 400, 600, 30, 70, 20);
    }

    static final List<Food> FOODS = List.of(
        food("1", "Phở bò tái", "pho bo tai", List.of("pho tai", "pho bo tai lan")),
        food("2", "Phở bò chín", "pho bo chin", List.of("pho chin", "pho nam bo")),
        food("3", "Phở gà", "pho ga", List.of("pho ga ta")),
        food("4", "Cơm tấm sườn nướng", "com tam suon nuong", List.of("com tam suon", "com suon nuong")),
        food("5", "Bánh mì thịt", "banh mi thit", List.of("banh mi pate", "banh mi thit nguoi")),
        food("6", "Đậu hũ sốt cà", "dau hu sot ca", List.of("dau phu sot ca chua")));

    @Test
    void chuanHoaBoDauVaDd() {
        assertEquals("pho bo tai", VietText.normalize("Phở Bò Tái!"));
        assertEquals("dau hu sot ca", VietText.normalize("  Đậu hũ   sốt cà "));
        assertEquals("banh mi thit nuong", VietText.normalize("Bánh-mì (thịt) nướng"));
        assertEquals("", VietText.normalize(null));
        assertEquals(List.of("cha", "gio"), VietText.tokens("Chả giò"));
    }

    @Test
    void khopDungTenHoacAlias() {
        assertEquals("1", FoodMatcher.bestMatch(List.of("Phở bò tái"), FOODS).orElseThrow().food().id());
        assertEquals(1.0, FoodMatcher.bestMatch(List.of("Phở tái"), FOODS).orElseThrow().score());
        assertEquals("6", FoodMatcher.bestMatch(List.of("Đậu phụ sốt cà chua"), FOODS).orElseThrow().food().id());
    }

    @Test
    void khopTheoTuTrungNhau() {
        // "phở bò" có trong cả tái và chín: hòa điểm thì lấy searchName ngắn hơn
        FoodMatcher.Scored s = FoodMatcher.bestMatch(List.of("Phở bò"), FOODS).orElseThrow();
        assertEquals("1", s.food().id());
        assertTrue(s.score() >= FoodMatcher.MATCH_MIN && s.score() < 1);
        // tên tiếng Anh không khớp nhưng tên tiếng Việt khớp
        assertEquals("4", FoodMatcher.bestMatch(List.of("Broken rice", "Cơm tấm sườn"), FOODS)
            .orElseThrow().food().id());
    }

    @Test
    void khongKhopKhiQuaKhac() {
        assertTrue(FoodMatcher.bestMatch(List.of("Gà rán"), FOODS).isEmpty());
        assertTrue(FoodMatcher.bestMatch(List.of("Pizza"), FOODS).isEmpty());
        assertTrue(FoodMatcher.bestMatch(List.of(""), FOODS).isEmpty());
    }

    @Test
    void timKiemKhongDauVaDangGoDo() {
        List<String> pho = FoodMatcher.search("pho", FOODS).stream().map(Food::id).toList();
        assertEquals(List.of("3", "1", "2"), pho);          // cùng điểm thì tên ngắn trước
        assertEquals("5", FoodMatcher.search("bánh m", FOODS).get(0).id());
        assertEquals("1", FoodMatcher.search("pho bo tai", FOODS).get(0).id());
        assertTrue(FoodMatcher.search("   ", FOODS).isEmpty());
        assertTrue(FoodMatcher.search("sushi", FOODS).isEmpty());
    }
}
