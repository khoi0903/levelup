package vn.levelup.nutrition.dto;

import java.time.Instant;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Admin duyệt món chưa có trong kho (food_candidates) vào kho foods. */
public final class FoodCandidateDtos {

    private FoodCandidateDtos() {}

    /** Số liệu cho 100 g. */
    public record Per100g(double kcal, double proteinG, double carbsG, double fatG) {}

    /**
     * Một món chờ duyệt. suggested: số gợi ý cho 100 g (người dùng đã lưu, hoặc AI ước tính), có thể null.
     * readyForReview: đủ số người dùng khác nhau để nên duyệt.
     */
    public record CandidateView(String id, String nameVi, String status, int userCount, int sightings, int saves,
                                Per100g suggested, Double typicalGrams, boolean readyForReview, Instant lastSeenAt,
                                String foodId) {}

    /** Số liệu cho một khẩu phần servingGrams, giống định dạng mongo/seed/foods.json. */
    public record ApproveRequest(
        @NotBlank @Size(max = 100) String nameVi,
        @NotNull @Pattern(regexp = "com|bun_pho_mi|banh_mi|xoi|mon_canh|mon_chay|an_vat|do_uong|trai_cay|trang_mieng")
        String category,
        @NotBlank @Size(max = 60) String servingDesc,
        @NotNull @DecimalMin("1") @DecimalMax("3000") Double servingGrams,
        @NotNull @DecimalMin("0") @DecimalMax("3000") Double kcal,
        @NotNull @DecimalMin("0") @DecimalMax("300") Double proteinG,
        @NotNull @DecimalMin("0") @DecimalMax("500") Double carbsG,
        @NotNull @DecimalMin("0") @DecimalMax("300") Double fatG
    ) {}
}
