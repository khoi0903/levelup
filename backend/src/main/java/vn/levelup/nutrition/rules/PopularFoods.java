package vn.levelup.nutrition.rules;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import vn.levelup.nutrition.model.Food;

/**
 * Món gợi ý nhanh theo bữa (GET /foods/popular): món người dùng hay ghi trước, rồi danh sách món Việt phổ biến.
 * Tên trong danh sách phải đúng nameVi của kho (mongo/seed/foods.json), có test kiểm tra.
 */
public final class PopularFoods {

    public static final int DEFAULT_LIMIT = 8;
    public static final int MAX_LIMIT = 20;
    /** Chỉ tính các bữa đã ghi trong 30 ngày gần nhất. */
    public static final int LOOKBACK_DAYS = 30;

    static final Map<String, List<String>> CURATED = Map.of(
        "breakfast", List.of("Phở bò tái", "Bánh mì thịt", "Bánh mì trứng", "Xôi đậu xanh", "Bánh cuốn",
            "Bún bò Huế", "Phở gà", "Xôi mặn", "Bánh bao nhân thịt", "Hủ tiếu Nam Vang", "Bánh giò",
            "Cà phê sữa đá", "Sữa đậu nành có đường", "Bún riêu cua", "Xôi gà", "Bánh mì gà xé", "Miến gà",
            "Cà phê đen không đường", "Sữa tươi có đường", "Chuối chín"),
        "lunch", List.of("Cơm tấm sườn nướng", "Cơm gà luộc", "Cơm thịt kho trứng", "Bún chả Hà Nội",
            "Cơm cá kho", "Bún thịt nướng", "Cơm rang dưa bò", "Canh chua cá", "Cơm trứng ốp la", "Mì Quảng",
            "Bún đậu mắm tôm", "Cơm chay đậu hũ", "Cơm tấm sườn bì chả", "Cơm gà xối mỡ", "Cơm thịt nướng",
            "Bún bò Huế", "Phở bò chín", "Hủ tiếu Nam Vang", "Cơm chiên trứng", "Mì xào bò"),
        "dinner", List.of("Cơm trắng", "Thịt kho tàu", "Canh rau ngót thịt bằm", "Cá basa kho tộ", "Gà kho gừng",
            "Canh bí đao thịt bằm", "Đậu hũ sốt cà chua", "Canh chua cá", "Cơm thịt kho trứng", "Phở gà",
            "Miến gà", "Gỏi cuốn tôm thịt", "Cơm cá kho", "Bún cá", "Cơm gà luộc", "Cơm bò lúc lắc",
            "Bánh xèo", "Bún riêu cua", "Cơm chiên hải sản", "Phở cuốn"),
        "snack", List.of("Chuối chín", "Sữa chua có đường", "Táo", "Trà sữa trân châu", "Cà phê sữa đá", "Cam",
            "Bánh tráng trộn", "Ổi", "Chè đậu xanh", "Bánh flan", "Nước dừa tươi", "Xoài chín", "Dưa hấu",
            "Sinh tố bơ", "Nước cam ép", "Thanh long", "Đu đủ chín", "Bạc xỉu", "Khoai tây chiên", "Nước mía"));

    private PopularFoods() {}

    public static boolean validMeal(String meal) {
        return meal != null && CURATED.containsKey(meal);
    }

    /** Danh sách món phổ biến của một bữa (tên đúng như trong kho); bữa lạ trả rỗng. */
    public static List<String> curated(String meal) {
        return CURATED.getOrDefault(meal, List.of());
    }

    /** limit ngoài 1–20 thì kéo về trong khoảng. */
    public static int clampLimit(int limit) {
        return Math.max(1, Math.min(MAX_LIMIT, limit));
    }

    /** Xếp foodId theo số lần ghi giảm dần; bằng nhau thì giữ thứ tự gặp trước (bữa mới nhất trước). */
    public static List<String> rank(List<String> loggedFoodIdsNewestFirst) {
        Map<String, Integer> counts = new LinkedHashMap<>();
        for (String id : loggedFoodIdsNewestFirst) {
            if (id != null) {
                counts.merge(id, 1, Integer::sum);
            }
        }
        return counts.entrySet().stream()
            .sorted(Map.Entry.<String, Integer>comparingByValue(Comparator.reverseOrder()))
            .map(Map.Entry::getKey).toList();
    }

    /**
     * Ghép: món của người dùng (theo rankedFoodIds, bỏ id không còn trong kho) rồi tới món phổ biến của bữa,
     * không trùng, tối đa limit.
     */
    public static List<Food> merge(List<String> rankedFoodIds, String meal, List<Food> catalog, int limit) {
        Map<String, Food> byId = new LinkedHashMap<>();
        Map<String, Food> byName = new LinkedHashMap<>();
        for (Food f : catalog) {
            byId.put(f.id(), f);
            byName.putIfAbsent(f.nameVi(), f);
        }
        List<Food> out = new ArrayList<>();
        Set<String> seen = new LinkedHashSet<>();
        int max = clampLimit(limit);
        for (String id : rankedFoodIds) {
            Food f = byId.get(id);
            if (f != null && out.size() < max && seen.add(f.id())) {
                out.add(f);
            }
        }
        for (String name : curated(meal)) {
            Food f = byName.get(name);
            if (f != null && out.size() < max && seen.add(f.id())) {
                out.add(f);
            }
        }
        return out;
    }
}
