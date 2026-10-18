package vn.levelup.nutrition.dto;

import java.util.List;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import vn.levelup.nutrition.model.Food;

/** Request/response của POST /meals/recognize. */
public final class RecognitionDtos {

    private RecognitionDtos() {}

    /**
     * Ảnh gửi thẳng dạng base64 (dev chưa có Firebase Storage). Tối đa 2 MB sau khi giải mã.
     * sha256: hex của đúng các byte ảnh, app tính trước khi gửi, dùng để không gọi AI lại cho cùng ảnh.
     */
    public record RecognizeRequest(
        @NotBlank String imageBase64,
        @NotNull @Pattern(regexp = "image/(jpeg|png|webp)") String mediaType,
        @NotNull @Pattern(regexp = "[0-9a-fA-F]{64}") String sha256
    ) {}

    public record RecognitionResponse(String recognitionId, boolean cached, List<Item> items) {}

    /**
     * Một món AI nhận ra. matched = false khi không có trong kho: foodId null. Khi đó nếu AI ước tính được
     * (estimated = true) thì có số liệu kèm khoảng ±25%, ngược lại số liệu để null; app cho người dùng
     * sửa, tìm món (GET /foods/search) hoặc nhập tay.
     */
    public record Item(
        String name,
        String foodId,
        String nameVi,
        double portionGrams,
        Integer kcal,
        Integer kcalMin,
        Integer kcalMax,
        Double proteinG,
        Double carbsG,
        Double fatG,
        double confidence,
        boolean matched,
        List<String> ingredients,
        boolean estimated
    ) {}

    /** Một món trong kết quả tìm kiếm, số liệu cho một khẩu phần chuẩn. */
    public record FoodView(String foodId, String nameVi, String category, String servingDesc, double servingGrams,
                           double kcal, double proteinG, double carbsG, double fatG) {
        public static FoodView of(Food f) {
            return new FoodView(f.id(), f.nameVi(), f.category(), f.servingDesc(), f.servingGrams(), f.kcal(),
                f.proteinG(), f.carbsG(), f.fatG());
        }
    }
}
