package vn.levelup.nutrition.rules;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Câu nhận xét sau khi lưu bữa (docs/content/meal-comments.json): chọn tình huống theo số liệu bữa và cả ngày,
 * rồi ghép một câu "mo" với một câu "ket" chưa dùng gần đây. Logic thuần, không Spring/DB.
 */
public final class MealComments {

    private MealComments() {}

    /** Gần chạm mục tiêu: còn từ 0 tới mức này. */
    static final int NEAR_TARGET_KCAL = 150;
    static final int LATE_HOUR = 21;
    static final int LATE_MIN_KCAL = 300;
    static final int MACRO_MIN_KCAL = 250;

    /**
     * Số liệu để chọn tình huống.
     * @param meal breakfast | lunch | dinner | snack
     * @param hour giờ ăn theo múi giờ người dùng (0–23)
     * @param targetKcal mục tiêu ngày, null khi chưa có (bỏ các tình huống so với mục tiêu)
     * @param dayKcalAfter tổng kcal hôm nay đã gồm bữa này
     * @param floorKcal mức sàn an toàn (1200, nam 1500)
     */
    public record Input(String meal, int hour, int mealKcal, double proteinG, double carbsG, double fatG,
                        Integer targetKcal, int dayKcalAfter, int floorKcal) {}

    /** Tình huống theo thứ tự ưu tiên: vượt ngày, ăn quá ít, ăn khuya, gần đủ, bữa nặng, macro, loại bữa. */
    public static String situation(Input in) {
        Integer target = in.targetKcal();
        if (target != null && in.dayKcalAfter() > target) {
            return "vuot_ngay";
        }
        if (("dinner".equals(in.meal()) || in.hour() >= 20) && in.dayKcalAfter() < in.floorKcal()) {
            return "an_qua_it";
        }
        if ((in.hour() >= LATE_HOUR || in.hour() < 4) && in.mealKcal() >= LATE_MIN_KCAL) {
            return "an_khuya";
        }
        if (target != null && target - in.dayKcalAfter() <= NEAR_TARGET_KCAL) {
            return "gan_du";
        }
        if (target != null && in.mealKcal() >= 0.4 * target) {
            return "bua_nang";
        }
        double macroKcal = 4 * in.proteinG() + 4 * in.carbsG() + 9 * in.fatG();
        if (macroKcal > 0 && in.mealKcal() >= MACRO_MIN_KCAL) {
            if (9 * in.fatG() / macroKcal >= 0.40) {
                return "nhieu_beo";
            }
            if (4 * in.carbsG() / macroKcal >= 0.65) {
                return "nhieu_tinh_bot";
            }
        }
        if (macroKcal > 0 && in.proteinG() >= 20 && 4 * in.proteinG() / macroKcal >= 0.30) {
            return "nhieu_dam";
        }
        if ("snack".equals(in.meal())) {
            return "an_vat";
        }
        if (target != null && in.mealKcal() < 0.15 * target) {
            return "bua_nhe";
        }
        if ("breakfast".equals(in.meal())) {
            return "bua_sang";
        }
        return "can_bang";
    }

    /**
     * Chọn một chỉ số trong [0, size) chưa có trong recent (mới nhất trước). Đã dùng hết thì chỉ tránh
     * lần dùng gần nhất. seed cố định thì kết quả cố định (test được, gửi lại không đổi câu).
     */
    public static int pick(int size, List<Integer> recent, long seed) {
        if (size <= 1) {
            return 0;
        }
        Set<Integer> used = Set.copyOf(recent.stream().filter(i -> i != null && i >= 0 && i < size).toList());
        List<Integer> free = new ArrayList<>();
        for (int i = 0; i < size; i++) {
            if (!used.contains(i)) {
                free.add(i);
            }
        }
        if (free.isEmpty()) {
            Integer last = recent.isEmpty() ? null : recent.get(0);
            for (int i = 0; i < size; i++) {
                if (last == null || i != last) {
                    free.add(i);
                }
            }
        }
        return free.get((int) Math.floorMod(seed, (long) free.size()));
    }

    /** Điền {ten} {mon} {kcal}...; chỗ trống không có giá trị bị bỏ, gọn khoảng trắng. */
    public static String fill(String template, Map<String, String> vars) {
        String text = template;
        for (var e : vars.entrySet()) {
            text = text.replace("{" + e.getKey() + "}", e.getValue() == null ? "" : e.getValue());
        }
        return text.replaceAll("\\{[a-z_]+}", "").replaceAll(" {2,}", " ").replace(" ,", ",").trim();
    }
}
