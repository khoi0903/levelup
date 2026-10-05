package vn.levelup.nutrition;

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

/** Request/response của POST /meals, GET /nutrition/today, POST /water. Giá trị enum khớp validator meal_logs. */
public final class MealDtos {

    private MealDtos() {}

    /**
     * Bữa ăn sau khi người dùng đã sửa khẩu phần. Món có foodId thì server tự tính lại số liệu từ kho,
     * không tin kcal app gửi. Món nhập tay (không foodId) bắt buộc có kcal, giới hạn trong khoảng hợp lý.
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
        @DecimalMin("1") @DecimalMax("3000") Double portionGrams,
        @DecimalMin("0") @DecimalMax("3000") Double kcal,
        @DecimalMin("0") @DecimalMax("300") Double proteinG,
        @DecimalMin("0") @DecimalMax("500") Double carbsG,
        @DecimalMin("0") @DecimalMax("300") Double fatG
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
     */
    public record TodayView(
        String localDate,
        NutritionRules.Target target,
        Totals consumed,
        Totals remaining,
        int waterMl,
        List<MealView> meals,
        Suggestion suggestion,
        int burnedKcal
    ) {}
}
