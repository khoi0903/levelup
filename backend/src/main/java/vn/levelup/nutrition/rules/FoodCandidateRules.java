package vn.levelup.nutrition.rules;

import java.util.List;
import java.util.function.ToDoubleFunction;

/**
 * Món chưa có trong kho (food_candidates): gợi ý số liệu cho 100 g để Admin duyệt vào kho foods.
 * Ưu tiên số người dùng đã lưu (có số gam), không có thì lấy số AI ước tính. Dùng trung vị để một số sai không kéo lệch.
 */
public final class FoodCandidateRules {

    /** Người dùng cần thấy món này ít nhất bấy nhiêu người khác nhau thì Admin mới nên duyệt. */
    public static final int SUGGEST_REVIEW_USERS = 5;

    /** Một lần người dùng lưu món: số liệu của cả khẩu phần (grams có thể null khi nhập tay). */
    public record Saved(Double grams, double kcal, double proteinG, double carbsG, double fatG) {}

    private FoodCandidateRules() {}

    /** Số liệu gợi ý cho 100 g, null khi chưa có dữ liệu nào dùng được. */
    public static RecognitionParser.Estimate suggestPer100g(List<Saved> saved, List<RecognitionParser.Estimate> ai) {
        List<RecognitionParser.Estimate> fromUsers = saved.stream()
            .filter(s -> s.grams() != null && s.grams() > 0 && s.kcal() > 0)
            .map(s -> {
                double f = 100 / s.grams();
                return new RecognitionParser.Estimate(s.kcal() * f, s.proteinG() * f, s.carbsG() * f, s.fatG() * f);
            })
            .filter(e -> e.kcal() <= RecognitionParser.Estimate.MAX_KCAL)
            .toList();
        List<RecognitionParser.Estimate> source = fromUsers.isEmpty() ? ai : fromUsers;
        if (source.isEmpty()) {
            return null;
        }
        return new RecognitionParser.Estimate(Math.round(median(source, RecognitionParser.Estimate::kcal)),
            NutritionRules.round1(median(source, RecognitionParser.Estimate::proteinG)),
            NutritionRules.round1(median(source, RecognitionParser.Estimate::carbsG)),
            NutritionRules.round1(median(source, RecognitionParser.Estimate::fatG)));
    }

    /** Khẩu phần thường gặp (trung vị số gam người dùng lưu), null khi không ai nhập số gam. */
    public static Double typicalGrams(List<Saved> saved) {
        List<Saved> withGrams = saved.stream().filter(s -> s.grams() != null && s.grams() > 0).toList();
        return withGrams.isEmpty() ? null : (double) Math.round(median(withGrams, Saved::grams));
    }

    static <T> double median(List<T> values, ToDoubleFunction<T> field) {
        double[] sorted = values.stream().mapToDouble(field).sorted().toArray();
        int mid = sorted.length / 2;
        return sorted.length % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
    }
}
