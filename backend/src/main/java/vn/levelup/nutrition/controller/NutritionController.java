package vn.levelup.nutrition.controller;

import java.io.IOException;
import java.util.Base64;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.server.ResponseStatusException;

import jakarta.validation.Valid;
import vn.levelup.identity.service.CurrentUserService;
import vn.levelup.nutrition.dto.MealDtos;
import vn.levelup.nutrition.dto.RecognitionDtos;
import vn.levelup.nutrition.rules.FoodMatcher;
import vn.levelup.nutrition.service.FoodCatalog;
import vn.levelup.nutrition.service.MealRecognitionService;
import vn.levelup.nutrition.service.NutritionService;
import vn.levelup.nutrition.service.PopularFoodService;

@RestController
public class NutritionController {

    /** Độ dài base64 tối đa ứng với 2 MB ảnh (kèm dư cho phần đệm). */
    private static final int MAX_BASE64_CHARS = (MealRecognitionService.MAX_IMAGE_BYTES + 2) / 3 * 4 + 4;

    private final MealRecognitionService recognition;
    private final NutritionService nutrition;
    private final FoodCatalog foods;
    private final CurrentUserService currentUser;
    private final PopularFoodService popular;

    public NutritionController(MealRecognitionService recognition, NutritionService nutrition, FoodCatalog foods,
                               CurrentUserService currentUser, PopularFoodService popular) {
        this.popular = popular;
        this.recognition = recognition;
        this.nutrition = nutrition;
        this.foods = foods;
        this.currentUser = currentUser;
    }

    /**
     * Nhận diện món từ ảnh gửi dạng base64. Lỗi: 413 IMAGE_TOO_LARGE, 400 SHA256_MISMATCH,
     * 429 PHOTO_LIMIT_REACHED, 503 AI_UNAVAILABLE (không trừ lượt), 502 AI_BAD_OUTPUT.
     */
    @PostMapping(path = "/meals/recognize", consumes = MediaType.APPLICATION_JSON_VALUE)
    public RecognitionDtos.RecognitionResponse recognize(@Valid @RequestBody RecognitionDtos.RecognizeRequest r) {
        var user = currentUser.require();
        String b64 = r.imageBase64();
        int comma = b64.indexOf(',');
        if (b64.startsWith("data:") && comma > 0) {
            b64 = b64.substring(comma + 1);           // bỏ tiền tố "data:image/jpeg;base64,"
        }
        if (b64.length() > MAX_BASE64_CHARS) {
            throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE, "IMAGE_TOO_LARGE");
        }
        byte[] image;
        try {
            image = Base64.getMimeDecoder().decode(b64);
        } catch (IllegalArgumentException e) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_IMAGE");
        }
        return recognition.recognize(user, image, r.mediaType(), r.sha256());
    }

    /** Cùng chức năng, ảnh gửi dạng multipart: phần "image" và tham số "sha256". */
    @PostMapping(path = "/meals/recognize", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public RecognitionDtos.RecognitionResponse recognizeMultipart(@RequestPart("image") MultipartFile image,
                                                                  @RequestParam("sha256") String sha256)
            throws IOException {
        var user = currentUser.require();
        if (image.getSize() > MealRecognitionService.MAX_IMAGE_BYTES) {
            throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE, "IMAGE_TOO_LARGE");
        }
        return recognition.recognize(user, image.getBytes(), image.getContentType(), sha256);
    }

    /**
     * Nhận diện món từ câu người dùng gõ ("2 bát phở bò, 1 ly trà đá"). Trả cùng dạng với /meals/recognize:
     * app mở màn sửa bữa rồi lưu bằng POST /meals với method "photo" + recognitionId. Dùng chung lượt
     * trong ngày với ảnh; cùng câu gửi lại thì cached = true, không trừ lượt.
     * Lỗi: 400 INVALID_TEXT, 429 PHOTO_LIMIT_REACHED, 503 AI_UNAVAILABLE (không trừ lượt), 502 AI_BAD_OUTPUT.
     */
    @PostMapping("/meals/parse")
    public RecognitionDtos.RecognitionResponse parse(@Valid @RequestBody RecognitionDtos.ParseRequest r) {
        return recognition.parseText(currentUser.require(), r.text(), r.meal());
    }

    /**
     * Món gợi ý nhanh cho một bữa (breakfast | lunch | dinner | snack): món người dùng ghi nhiều nhất cho bữa đó
     * trong 30 ngày trước, rồi tới danh sách món Việt phổ biến của bữa; không trùng. limit mặc định 8, tối đa 20.
     */
    @GetMapping("/foods/popular")
    public List<RecognitionDtos.FoodView> popular(@RequestParam("meal") String meal,
                                                  @RequestParam(name = "limit", defaultValue = "8") int limit) {
        return popular.popular(currentUser.require(), meal, limit);
    }

    /** Tìm món trong kho để nhập tay: tối đa 20 món, gõ không dấu cũng được. */
    @GetMapping("/foods/search")
    public List<RecognitionDtos.FoodView> search(@RequestParam("q") String q) {
        currentUser.require();
        if (q.length() > 100) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "QUERY_TOO_LONG");
        }
        return FoodMatcher.search(q, foods.all()).stream().map(RecognitionDtos.FoodView::of).toList();
    }

    /** Lưu bữa sau khi người dùng sửa khẩu phần; trả về tổng kết hôm nay và gợi ý nếu còn thiếu đạm. */
    @PostMapping("/meals")
    public MealDtos.TodayView saveMeal(@Valid @RequestBody MealDtos.MealRequest r) {
        return nutrition.saveMeal(currentUser.require(), r);
    }

    @GetMapping("/nutrition/today")
    public MealDtos.TodayView today() {
        return nutrition.today(currentUser.require());
    }

    @PostMapping("/water")
    public MealDtos.WaterView water(@Valid @RequestBody MealDtos.WaterRequest r) {
        return nutrition.addWater(currentUser.require(), r.ml());
    }
}
