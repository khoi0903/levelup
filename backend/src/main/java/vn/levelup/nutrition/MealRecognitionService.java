package vn.levelup.nutrition;

import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Date;
import java.util.HexFormat;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import vn.levelup.coach.AiClient;
import vn.levelup.common.LocalDates;
import vn.levelup.users.User;

/**
 * POST /meals/recognize (F8): ảnh → AI nhận diện món → ghép kho món Việt → khoảng kcal.
 * Ảnh không bao giờ được lưu vào MongoDB, chỉ lưu sha256 và kết quả đã kiểm tra.
 * Cùng ảnh (cùng sha256, cùng người dùng) thì dùng lại kết quả cũ: không gọi AI, không trừ lượt.
 */
@Service
public class MealRecognitionService {

    private static final Logger log = LoggerFactory.getLogger(MealRecognitionService.class);

    public static final int MAX_IMAGE_BYTES = 2 * 1024 * 1024;
    static final int MAX_TOKENS = 1024;

    static final String SYSTEM = """
        Bạn là chuyên gia dinh dưỡng, nhận diện món ăn Việt Nam từ ảnh.
        Chỉ trả về đúng một object JSON, không kèm chữ nào khác, theo dạng:
        {"dishes":[{"name":"tên tiếng Anh","nameVi":"tên món tiếng Việt có dấu",\
        "ingredients":["thành phần chính"],"portionGrams":số gam ước lượng của phần trong ảnh,\
        "confidence":số từ 0 đến 1}]}
        Dùng tên món Việt phổ biến, ví dụ: Phở bò tái, Cơm tấm sườn nướng, Bánh mì thịt, Bún chả Hà Nội.
        Tối đa 10 món. Ảnh không có món ăn thì trả {"dishes":[]}.""";
    static final String PROMPT = "Nhận diện các món trong ảnh và ước lượng khẩu phần.";
    static final String RETRY_PROMPT = PROMPT
        + " Lần trước bạn trả JSON không hợp lệ. Chỉ trả JSON đúng dạng đã nêu, không thêm chữ nào khác.";

    private final MongoTemplate mongo;
    private final AiClient ai;
    private final FoodCatalog foods;
    private final Clock clock;
    private final int dailyLimit;
    private final String model;

    public MealRecognitionService(MongoTemplate mongo, AiClient ai, FoodCatalog foods, Clock clock,
                                  @Value("${levelup.nutrition.daily-photo-limit:10}") int dailyLimit,
                                  @Value("${levelup.ai.model:claude-opus-5-5}") String model) {
        this.mongo = mongo;
        this.ai = ai;
        this.foods = foods;
        this.clock = clock;
        this.dailyLimit = dailyLimit;
        this.model = model;
    }

    public RecognitionDtos.RecognitionResponse recognize(User user, byte[] image, String mediaType, String sha256) {
        if (image == null || image.length == 0) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_IMAGE");
        }
        if (image.length > MAX_IMAGE_BYTES) {
            throw new ResponseStatusException(HttpStatus.PAYLOAD_TOO_LARGE, "IMAGE_TOO_LARGE");
        }
        if (mediaType == null || !mediaType.matches("image/(jpeg|png|webp)")) {
            throw new ResponseStatusException(HttpStatus.UNSUPPORTED_MEDIA_TYPE, "UNSUPPORTED_IMAGE_TYPE");
        }
        String hash = sha256Hex(image);
        if (sha256 == null || !hash.equals(sha256.toLowerCase(Locale.ROOT))) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "SHA256_MISMATCH");
        }
        ObjectId userId = new ObjectId(user.id());

        // 1. Cache: ảnh này người dùng đã gửi rồi
        Document cached = mongo.findOne(Query.query(Criteria.where("userId").is(userId).and("imageSha256").is(hash))
            .with(Sort.by(Sort.Direction.DESC, "createdAt")), Document.class, "food_recognitions");
        if (cached != null) {
            return response(cached.getObjectId("_id"), true, dishesFrom(cached));
        }

        // 2. AI chưa cấu hình: báo ngay, không trừ lượt
        if (!ai.available()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "AI_UNAVAILABLE");
        }

        // 3. Giữ một lượt trong ngày, gọi AI lỗi thì trả lại lượt
        String localDate = LocalDates.today(user.timezone(), clock).toString();
        if (!reserveScan(userId, localDate)) {
            throw new ResponseStatusException(HttpStatus.TOO_MANY_REQUESTS, "PHOTO_LIMIT_REACHED");
        }
        long started = System.nanoTime();
        List<RecognitionParser.Dish> dishes;
        int attempts = 0;
        try {
            dishes = null;
            while (dishes == null) {
                attempts++;
                String raw = ai.completeWithImage(SYSTEM, attempts == 1 ? PROMPT : RETRY_PROMPT, image, mediaType,
                    MAX_TOKENS);
                try {
                    dishes = RecognitionParser.parse(raw);
                } catch (RecognitionParser.InvalidOutputException e) {
                    log.warn("AI trả kết quả nhận diện món không hợp lệ (lần {}): {}", attempts, e.getMessage());
                    if (attempts >= 2) {
                        // Đã gọi AI thật hai lần nên vẫn tính lượt
                        throw new ResponseStatusException(HttpStatus.BAD_GATEWAY, "AI_BAD_OUTPUT");
                    }
                }
            }
        } catch (AiClient.AiUnavailableException e) {
            refundScan(userId, localDate);
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "AI_UNAVAILABLE");
        }
        long latencyMs = (System.nanoTime() - started) / 1_000_000;

        // 4. Lưu kết quả đã kiểm tra (không lưu ảnh)
        ObjectId id = new ObjectId();
        Document rec = new Document("_id", id)
            .append("userId", userId)
            .append("imageSha256", hash)
            .append("model", model)
            .append("rawResult", new Document("dishes", dishes.stream().map(MealRecognitionService::dishDocument)
                .toList()))
            .append("latencyMs", latencyMs)
            .append("attempts", attempts)
            .append("localDate", localDate)
            .append("createdAt", Date.from(Instant.now(clock)));
        mongo.insert(rec, "food_recognitions");
        return response(id, false, dishes);
    }

    /** Tăng photoScans nếu còn lượt, trong một lệnh. Hết lượt thì upsert đụng index unique → false. */
    boolean reserveScan(ObjectId userId, String localDate) {
        Query q = Query.query(Criteria.where("userId").is(userId).and("localDate").is(localDate)
            .orOperator(Criteria.where("usage.photoScans").lt(dailyLimit),
                Criteria.where("usage.photoScans").exists(false)));
        for (int i = 0; i < 2; i++) {          // lần 2: hai request cùng tạo document của ngày
            try {
                mongo.upsert(q, new Update().inc("usage.photoScans", 1), "daily_stats");
                return true;
            } catch (DuplicateKeyException e) {
                // document của ngày đã có và đã hết lượt, hoặc vừa bị request khác tạo
            }
        }
        return false;
    }

    private void refundScan(ObjectId userId, String localDate) {
        mongo.updateFirst(Query.query(Criteria.where("userId").is(userId).and("localDate").is(localDate)
            .and("usage.photoScans").gt(0)), new Update().inc("usage.photoScans", -1), "daily_stats");
    }

    private RecognitionDtos.RecognitionResponse response(ObjectId id, boolean cached,
                                                         List<RecognitionParser.Dish> dishes) {
        List<Food> catalog = foods.all();
        List<RecognitionDtos.Item> items = new ArrayList<>();
        for (RecognitionParser.Dish d : dishes) {
            Optional<FoodMatcher.Scored> match = FoodMatcher.bestMatch(List.of(d.nameVi(), d.name()), catalog);
            if (match.isPresent()) {
                Food f = match.get().food();
                NutritionRules.Portion p = NutritionRules.portion(f, d.portionGrams());
                items.add(new RecognitionDtos.Item(d.name(), f.id(), f.nameVi(), d.portionGrams(), p.kcal(),
                    p.kcalMin(), p.kcalMax(), p.proteinG(), p.carbsG(), p.fatG(), d.confidence(), true,
                    d.ingredients()));
            } else {
                items.add(new RecognitionDtos.Item(d.name(), null, d.nameVi(), d.portionGrams(), null, null, null,
                    null, null, null, d.confidence(), false, d.ingredients()));
            }
        }
        return new RecognitionDtos.RecognitionResponse(id.toHexString(), cached, items);
    }

    static Document dishDocument(RecognitionParser.Dish d) {
        return new Document("name", d.name()).append("nameVi", d.nameVi()).append("ingredients", d.ingredients())
            .append("portionGrams", d.portionGrams()).append("confidence", d.confidence());
    }

    static List<RecognitionParser.Dish> dishesFrom(Document recognition) {
        Document raw = recognition.get("rawResult", Document.class);
        if (raw == null) {
            return List.of();
        }
        return raw.getList("dishes", Document.class, List.of()).stream()
            .map(d -> new RecognitionParser.Dish(d.getString("name"), d.getString("nameVi"),
                d.getList("ingredients", String.class, List.of()), ((Number) d.get("portionGrams")).doubleValue(),
                ((Number) d.get("confidence")).doubleValue()))
            .toList();
    }

    static String sha256Hex(byte[] data) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(data));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
