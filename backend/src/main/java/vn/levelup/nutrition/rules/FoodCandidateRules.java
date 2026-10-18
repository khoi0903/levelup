package vn.levelup.nutrition.rules;

import java.util.List;
import java.util.function.ToDoubleFunction;

/**
 * Món chưa có trong kho (food_candidates): gợi ý số liệu để Admin duyệt vào kho foods.
 * Số /100 g lấy trung vị các lần AI ước tính (một lần sai không kéo lệch); khẩu phần lấy trung vị số gam
 * người dùng đã lưu (người dùng chỉ sửa được số gam, calo do server tính).
 */
public final class FoodCandidateRules {

    /** Nên duyệt khi có ít nhất bấy nhiêu người dùng khác nhau gặp món này. */
    public static final int SUGGEST_REVIEW_USERS = 5;

    private FoodCandidateRules() {}

    /** Số liệu gợi ý cho 100 g, null khi AI chưa ước tính được lần nào. */
    public static RecognitionParser.Estimate suggestPer100g(List<RecognitionParser.Estimate> ai) {
        if (ai.isEmpty()) {
            return null;
        }
        return new RecognitionParser.Estimate(Math.round(median(ai, RecognitionParser.Estimate::kcal)),
            NutritionRules.round1(median(ai, RecognitionParser.Estimate::proteinG)),
            NutritionRules.round1(median(ai, RecognitionParser.Estimate::carbsG)),
            NutritionRules.round1(median(ai, RecognitionParser.Estimate::fatG)));
    }

    /** Khẩu phần thường gặp (trung vị số gam người dùng lưu), null khi chưa ai lưu. */
    public static Double typicalGrams(List<Double> grams) {
        List<Double> valid = grams.stream().filter(g -> g != null && g > 0).toList();
        return valid.isEmpty() ? null : (double) Math.round(median(valid, Double::doubleValue));
    }

    static <T> double median(List<T> values, ToDoubleFunction<T> field) {
        double[] sorted = values.stream().mapToDouble(field).sorted().toArray();
        int mid = sorted.length / 2;
        return sorted.length % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
    }
}
