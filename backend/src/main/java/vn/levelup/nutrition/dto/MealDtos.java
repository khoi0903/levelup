package vn.levelup.nutrition.dto;

import java.time.Instant;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import vn.levelup.nutrition.rules.NutritionRules;

/** Request/response của POST /meals, GET /nutrition/today, POST /water. Giá trị enum khớp validator meal_logs. */
public final class MealDtos {

    private MealDtos() {}

    /** Giới hạn số liệu một món (dùng chung cho Item và FoodCandidateDtos.ApproveRequest). */
    public static final String MAX_GRAMS = "3000";
    public static final String MAX_KCAL = "3000";
    public static final String MAX_PROTEIN_G = "300";
    public static final String MAX_CARBS_G = "500";
    public static final String MAX_FAT_G = "300";

    /**
     * Bữa ăn sau khi người dùng đã sửa khẩu phần. Món có foodId thì server tự tính lại số liệu từ kho,
     * món AI ước tính trong ảnh thì tính lại từ số /100 g theo số gam; không tin kcal app gửi.
     * Món nhập tay (không foodId) bắt buộc có kcal, giới hạn trong khoảng hợp lý.
     */
    public record MealRequest(
        @NotNull @Pattern(regexp = "breakfast|lunch|dinner|snack") String meal,
        @NotNull @Pattern(regexp = "photo|search|manual") String method,
        @Pattern(regexp = "[0-9a-f]{24}") String recognitionId,
        @NotEmpty @Size(max = 30) List<@Valid @NotNull Item> items,
        Instant eatenAt
    ) {}

    public record Item(
        @Pattern(regexp = "[0-9a-f]{24}") String foodId,
        @NotBlank @Size(max = 100) String name,
        @DecimalMin("1") @DecimalMax(MAX_GRAMS) Double portionGrams,
        @DecimalMin("0") @DecimalMax(MAX_KCAL) Double kcal,
        @DecimalMin("0") @DecimalMax(MAX_PROTEIN_G) Double proteinG,
        @DecimalMin("0") @DecimalMax(MAX_CARBS_G) Double carbsG,
        @DecimalMin("0") @DecimalMax(MAX_FAT_G) Double fatG
    ) {}

    public record WaterRequest(@NotNull @Min(50) @Max(2000) Integer ml) {}

    public record WaterView(String localDate, int waterMl, Integer targetMl) {}

    public record Totals(int kcal, double proteinG, double carbsG, double fatG) {}

    public record ItemView(String foodId, String name, Double grams, int kcal, double proteinG, double carbsG,
                           double fatG) {}

    public record MealView(String id, String meal, String method, Instant eatenAt, int kcal, Integer kcalMin,
                           Integer kcalMax, double proteinG, double carbsG, double fatG, List<ItemView> items) {}

    /** Gợi ý bữa tiếp theo khi cuối ngày còn thiếu đạm. */
    public record Suggestion(String message, List<RecognitionDtos.FoodView> foods) {}

    /**
     * Calo, macro, nước, các bữa hôm nay. target null khi người dùng chưa có mục tiêu;
     * remaining = target - consumed, có thể âm khi đã ăn vượt.
     * burnedKcal: calo đốt ước tính từ các buổi tập hôm nay, chỉ để xem (không cộng vào mục tiêu ăn).
     * steps, activeKcal: từ Health Connect (0 khi chưa kết nối). totalBurnedKcal = burnedKcal + calo vận động
     * ngoài giờ tập (NutritionRules.totalBurnedKcal; app cũ chưa gửi phần trùng giờ tập thì max như trước),
     * cũng chỉ để xem: mục tiêu ăn không tăng theo vận động.
     * comment: câu nhận xét bữa vừa lưu, chỉ có ở phản hồi POST /meals (GET /nutrition/today luôn null).
     */
    public record TodayView(
        String localDate,
        NutritionRules.Target target,
        Totals consumed,
        Totals remaining,
        int waterMl,
        List<MealView> meals,
        Suggestion suggestion,
        int burnedKcal,
        int steps,
        int activeKcal,
        int totalBurnedKcal,
        MealComment comment
    ) {
        /** Kèm câu nhận xét bữa vừa lưu (chỉ có trong phản hồi POST /meals). */
        public TodayView withComment(MealComment c) {
            return new TodayView(localDate, target, consumed, remaining, waterMl, meals, suggestion, burnedKcal,
                steps, activeKcal, totalBurnedKcal, c);
        }
    }

    /**
     * Câu nhận xét bữa vừa lưu theo phong cách coach (docs/content/meal-comments.json).
     * situation: vuot_ngay | gan_du | an_qua_it | an_khuya | bua_nang | nhieu_beo | nhieu_tinh_bot | nhieu_dam
     * | an_vat | bua_sang | bua_nhe | can_bang.
     */
    public record MealComment(String situation, String text) {}
}
