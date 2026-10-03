package vn.levelup.nutrition;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

import vn.levelup.users.User;

/** Luật của F8 không đọc hay ghi database, để unit test. */
public final class NutritionRules {

    /** Khoảng kcal hiển thị khi nhận diện ảnh: ±15% (docs: "550–650 kcal"). */
    static final double RANGE = 0.15;
    /** Gợi ý thêm đạm khi đã sau 15:00 và còn thiếu hơn 30 g. */
    static final LocalTime SUGGEST_AFTER = LocalTime.of(15, 0);
    static final double SUGGEST_PROTEIN_GAP_G = 30;
    static final double SUGGEST_MIN_FOOD_PROTEIN_G = 10;
    static final int SUGGEST_MAX_FOODS = 2;

    private NutritionRules() {}

    /** Số liệu của một khẩu phần portionGrams, tính theo tỉ lệ với khẩu phần chuẩn trong kho. */
    public record Portion(int kcal, int kcalMin, int kcalMax, double proteinG, double carbsG, double fatG) {}

    public static Portion portion(Food food, double portionGrams) {
        double factor = food.servingGrams() > 0 ? portionGrams / food.servingGrams() : 1;
        double kcal = food.kcal() * factor;
        return new Portion((int) Math.round(kcal), (int) Math.round(kcal * (1 - RANGE)),
            (int) Math.round(kcal * (1 + RANGE)), round1(food.proteinG() * factor),
            round1(food.carbsG() * factor), round1(food.fatG() * factor));
    }

    public static double round1(double v) {
        return Math.round(v * 10) / 10.0;
    }

    /** Mục tiêu trong ngày đã áp mức sàn. */
    public record Target(int kcal, int proteinG, int carbsG, int fatG, int waterMl) {}

    /** Mức sàn calo: 1200 kcal, nam 1500 kcal (AGENTS.md). */
    public static int kcalFloor(String gender) {
        return "male".equals(gender) ? NutritionCalculator.FLOOR_MALE : NutritionCalculator.FLOOR_DEFAULT;
    }

    /**
     * Mục tiêu đang áp dụng hôm nay: phần tử có effectiveFrom muộn nhất mà không sau hôm nay
     * (hòa thì lấy phần tử sau). Chưa có thì lấy phần tử cuối. Không bao giờ dưới mức sàn.
     */
    public static Target effectiveTarget(List<User.NutritionTarget> history, LocalDate today, String gender) {
        if (history == null || history.isEmpty()) {
            return null;
        }
        User.NutritionTarget chosen = null;
        for (User.NutritionTarget t : history) {
            if (t == null || t.effectiveFrom() == null || t.kcal() == null) {
                continue;
            }
            boolean active = !LocalDate.parse(t.effectiveFrom()).isAfter(today);
            if (active && (chosen == null || t.effectiveFrom().compareTo(chosen.effectiveFrom()) >= 0)) {
                chosen = t;
            }
        }
        if (chosen == null) {
            chosen = history.get(history.size() - 1);
        }
        return new Target(Math.max(kcalFloor(gender), chosen.kcal()), orZero(chosen.proteinG()),
            orZero(chosen.carbsG()), orZero(chosen.fatG()), orZero(chosen.waterMl()));
    }

    private static int orZero(Integer v) {
        return v == null ? 0 : v;
    }

    /** Cuối ngày (sau 15:00) mà còn thiếu hơn 30 g đạm thì gợi ý bữa tiếp theo. */
    public static boolean shouldSuggestProtein(LocalTime localTime, double proteinRemainingG) {
        return !localTime.isBefore(SUGGEST_AFTER) && proteinRemainingG > SUGGEST_PROTEIN_GAP_G;
    }

    /**
     * 1–2 món nhiều đạm vừa với lượng kcal còn lại: ưu tiên nhiều đạm trên mỗi kcal,
     * hai món khác nhóm. Món đầu đã đủ đạm thì chỉ gợi ý một món.
     */
    public static List<Food> proteinFoods(List<Food> foods, double kcalRemaining, double proteinRemainingG) {
        List<Food> sorted = foods.stream()
            .filter(f -> f.proteinG() >= SUGGEST_MIN_FOOD_PROTEIN_G && f.kcal() > 0 && f.kcal() <= kcalRemaining)
            .sorted(Comparator.comparingDouble((Food f) -> f.proteinG() / f.kcal()).reversed()
                .thenComparing(Food::searchName))
            .toList();
        List<Food> picked = new ArrayList<>();
        Set<String> categories = new HashSet<>();
        double kcalLeft = kcalRemaining;
        double proteinLeft = proteinRemainingG;
        for (Food f : sorted) {
            if (picked.size() == SUGGEST_MAX_FOODS || proteinLeft <= 0) {
                break;
            }
            if (f.kcal() <= kcalLeft && categories.add(String.valueOf(f.category()))) {
                picked.add(f);
                kcalLeft -= f.kcal();
                proteinLeft -= f.proteinG();
            }
        }
        return picked;
    }

    public static String suggestionMessage(double proteinRemainingG, List<Food> foods) {
        StringBuilder sb = new StringBuilder("Hôm nay bạn còn thiếu khoảng ")
            .append(Math.round(proteinRemainingG)).append(" g đạm. Bữa tới thử ");
        for (int i = 0; i < foods.size(); i++) {
            Food f = foods.get(i);
            if (i > 0) {
                sb.append(" và ");
            }
            sb.append(f.nameVi()).append(" (").append(format(f.proteinG())).append(" g đạm, ")
                .append(Math.round(f.kcal())).append(" kcal)");
        }
        return sb.append(" nhé.").toString();
    }

    private static String format(double v) {
        return v == Math.rint(v) ? String.valueOf((long) v) : String.format(Locale.ROOT, "%.1f", v);
    }
}
