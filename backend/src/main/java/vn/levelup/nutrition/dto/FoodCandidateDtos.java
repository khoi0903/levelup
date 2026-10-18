package vn.levelup.nutrition.dto;

import java.time.Instant;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import vn.levelup.nutrition.rules.RecognitionParser;

/** Admin duyệt món chưa có trong kho (food_candidates) vào kho foods. */
public final class FoodCandidateDtos {

    private FoodCandidateDtos() {}

    /**
     * Một món chờ duyệt. suggested: số gợi ý cho 100 g (trung vị AI ước tính), có thể null.
     * typicalGrams: khẩu phần người dùng hay lưu. readyForReview: đủ số người dùng khác nhau để nên duyệt.
     */
    public record CandidateView(String id, String nameVi, String status, int userCount, int sightings, int saves,
                                RecognitionParser.Estimate suggested, Double typicalGrams, boolean readyForReview,
                                Instant lastSeenAt, String foodId) {}

    /** Số liệu cho một khẩu phần servingGrams, giống định dạng mongo/seed/foods.json; giới hạn như MealDtos.Item. */
    public record ApproveRequest(
        @NotBlank @Size(max = 100) String nameVi,
        @NotNull @Pattern(regexp = "com|bun_pho_mi|banh_mi|xoi|mon_canh|mon_chay|an_vat|do_uong|trai_cay|trang_mieng")
        String category,
        @NotBlank @Size(max = 60) String servingDesc,
        @NotNull @DecimalMin("1") @DecimalMax(MealDtos.MAX_GRAMS) Double servingGrams,
        @NotNull @DecimalMin("0") @DecimalMax(MealDtos.MAX_KCAL) Double kcal,
        @NotNull @DecimalMin("0") @DecimalMax(MealDtos.MAX_PROTEIN_G) Double proteinG,
        @NotNull @DecimalMin("0") @DecimalMax(MealDtos.MAX_CARBS_G) Double carbsG,
        @NotNull @DecimalMin("0") @DecimalMax(MealDtos.MAX_FAT_G) Double fatG
    ) {}
}
