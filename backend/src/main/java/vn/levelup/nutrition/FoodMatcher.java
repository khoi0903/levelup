package vn.levelup.nutrition;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;

/**
 * Ghép tên món (AI trả về hoặc người dùng gõ) với kho foods, không đọc database.
 * Khớp đúng searchName/alias trước (điểm 1.0), sau đó chấm điểm theo số từ trùng nhau.
 */
public final class FoodMatcher {

    /** Ngưỡng để coi món AI nhận diện là đã khớp kho. */
    static final double MATCH_MIN = 0.6;
    /** Ngưỡng hiện trong kết quả tìm kiếm. */
    static final double SEARCH_MIN = 0.25;
    static final int SEARCH_LIMIT = 20;

    public record Scored(Food food, double score) {}

    private FoodMatcher() {}

    /**
     * Điểm giống nhau giữa câu tìm và một tên món (đều đã chuẩn hóa thành từ).
     * prefixLast: từ cuối của câu tìm được khớp theo tiền tố (người dùng đang gõ dở).
     */
    static double score(List<String> query, List<String> candidate, boolean prefixLast) {
        if (query.isEmpty() || candidate.isEmpty()) {
            return 0;
        }
        if (query.equals(candidate)) {
            return 1.0;
        }
        Set<String> q = new LinkedHashSet<>(query);
        Set<String> c = new LinkedHashSet<>(candidate);
        String last = query.get(query.size() - 1);
        int matched = 0;
        for (String t : q) {
            boolean partial = prefixLast && t.equals(last) && c.stream().anyMatch(w -> w.startsWith(t));
            if (c.contains(t) || partial) {
                matched++;
            }
        }
        if (matched == 0) {
            return 0;
        }
        double s = 0.6 * matched / q.size() + 0.35 * matched / c.size();
        String joined = String.join(" ", candidate);
        if (joined.startsWith(String.join(" ", query))) {
            s += 0.04;               // tên món bắt đầu bằng đúng câu tìm
        }
        return Math.min(s, 0.99);
    }

    /** Điểm của một món: lấy cao nhất giữa searchName và các alias. */
    static double score(List<String> query, Food food, boolean prefixLast) {
        double best = score(query, VietText.tokens(food.searchName()), prefixLast);
        for (String alias : food.aliases()) {
            best = Math.max(best, score(query, VietText.tokens(alias), prefixLast));
        }
        return best;
    }

    private static final Comparator<Scored> RANK = Comparator.comparingDouble(Scored::score).reversed()
        .thenComparingInt(s -> s.food().searchName().length())
        .thenComparing(s -> s.food().searchName());

    /** Món khớp nhất với một trong các tên (vd tên tiếng Việt và tên tiếng Anh AI trả về). */
    public static Optional<Scored> bestMatch(List<String> names, List<Food> foods) {
        Scored best = null;
        for (String name : names) {
            List<String> q = VietText.tokens(name);
            for (Food f : foods) {
                Scored s = new Scored(f, score(q, f, false));
                if (s.score() >= MATCH_MIN && (best == null || RANK.compare(s, best) < 0)) {
                    best = s;
                }
            }
        }
        return Optional.ofNullable(best);
    }

    /** Tìm món để nhập tay: tối đa 20 món, điểm cao trước. */
    public static List<Food> search(String query, List<Food> foods) {
        List<String> q = VietText.tokens(query);
        if (q.isEmpty()) {
            return List.of();
        }
        List<Scored> scored = new ArrayList<>();
        for (Food f : foods) {
            double s = score(q, f, true);
            if (s >= SEARCH_MIN) {
                scored.add(new Scored(f, s));
            }
        }
        return scored.stream().sorted(RANK).limit(SEARCH_LIMIT).map(Scored::food).toList();
    }
}
