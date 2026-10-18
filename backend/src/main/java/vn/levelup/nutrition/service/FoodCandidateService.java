package vn.levelup.nutrition.service;

import java.time.Clock;
import java.util.Date;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.FindAndModifyOptions;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.nutrition.dto.FoodCandidateDtos;
import vn.levelup.nutrition.model.Food;
import vn.levelup.nutrition.rules.FoodCandidateRules;
import vn.levelup.nutrition.rules.RecognitionParser;
import vn.levelup.nutrition.rules.VietText;

/**
 * Kho chờ food_candidates: món chưa có trong kho foods mà AI nhận ra trong ảnh.
 * Gom theo tên đã chuẩn hóa để sau này có dữ liệu món ăn; AI không ghi vào foods, chỉ Admin duyệt mới thêm vào kho.
 * Món đã duyệt/bỏ thì không ghi thêm. Lỗi ghi kho chờ không bao giờ làm hỏng việc nhận diện hay lưu bữa.
 */
@Service
public class FoodCandidateService {

    private static final Logger log = LoggerFactory.getLogger(FoodCandidateService.class);
    static final String COLLECTION = "food_candidates";
    /** Một dòng cho mỗi (món, người dùng): đếm số người khác nhau mà không giữ mảng userId lớn trong món. */
    static final String USERS = "food_candidate_users";
    static final int AI_SAMPLES = 20;
    static final int SAVED_SAMPLES = 50;

    private final MongoTemplate mongo;
    private final FoodCatalog foods;
    private final Clock clock;

    public FoodCandidateService(MongoTemplate mongo, FoodCatalog foods, Clock clock) {
        this.mongo = mongo;
        this.foods = foods;
        this.clock = clock;
    }

    /** AI nhận ra các món không có trong kho (trong một ảnh, cùng tên chỉ tính một lần). */
    public void recordRecognized(ObjectId userId, List<RecognitionParser.Dish> dishes) {
        Map<String, RecognitionParser.Dish> byKey = new LinkedHashMap<>();
        for (RecognitionParser.Dish d : dishes) {
            byKey.putIfAbsent(VietText.normalize(d.nameVi()), d);
        }
        byKey.forEach((key, dish) -> {
            Update u = base(dish.nameVi()).inc("sightings", 1);
            if (dish.per100g() != null) {
                u.push("aiSamples").slice(-AI_SAMPLES)
                    .each(MealRecognitionService.estimateDocument(dish.per100g()).append("at", now()));
            }
            record(userId, key, u);
        });
    }

    /** Người dùng lưu món AI ước tính: chỉ số gam là của người dùng (calo do server tính), giữ để gợi ý khẩu phần. */
    public void recordSaved(ObjectId userId, String name, double grams) {
        record(userId, VietText.normalize(name), base(name).inc("saves", 1).push("savedSamples").slice(-SAVED_SAMPLES)
            .each(new Document("grams", grams).append("at", now())));
    }

    public List<FoodCandidateDtos.CandidateView> list(String status, int limit) {
        Query q = Query.query(Criteria.where("status").is(status))
            .with(Sort.by(Sort.Direction.DESC, "userCount", "lastSeenAt")).limit(limit);
        return mongo.find(q, Document.class, COLLECTION).stream().map(FoodCandidateService::view).toList();
    }

    /**
     * Thêm món vào kho foods (source "ai", đã duyệt) và đánh dấu món chờ là approved, cùng admin_audit,
     * trong một transaction như các thay đổi admin khác.
     */
    @Transactional
    public FoodCandidateDtos.CandidateView approve(String adminUid, String id, FoodCandidateDtos.ApproveRequest r) {
        String searchName = VietText.normalize(r.nameVi());
        if (searchName.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_NAME");
        }
        ObjectId foodId = new ObjectId();
        // Giành món trong một lệnh: hai lần bấm duyệt cùng lúc chỉ một lần thêm vào kho
        Document candidate = claim(id, Update.update("status", "approved").set("foodId", foodId)
            .set("reviewedAt", now()).set("reviewedBy", adminUid));
        String original = VietText.normalize(candidate.getString("nameVi"));
        // Trùng tên hoặc alias của một món đã có (FoodMatcher coi alias là khớp tuyệt đối) thì không thêm
        Set<String> names = original.isEmpty() || original.equals(searchName) ? Set.of(searchName)
            : Set.of(searchName, original);
        for (Food f : foods.all()) {
            if (names.contains(VietText.normalize(f.searchName()))
                    || f.aliases().stream().map(VietText::normalize).anyMatch(names::contains)) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "FOOD_EXISTS");
            }
        }
        List<String> aliases = original.isEmpty() || original.equals(searchName) ? List.of() : List.of(original);
        mongo.insert(new Document("_id", foodId).append("nameVi", r.nameVi().trim()).append("searchName", searchName)
            .append("aliases", aliases).append("category", r.category()).append("servingDesc", r.servingDesc().trim())
            .append("servingGrams", r.servingGrams()).append("kcal", r.kcal()).append("proteinG", r.proteinG())
            .append("carbsG", r.carbsG()).append("fatG", r.fatG()).append("source", "ai").append("verified", true)
            .append("createdAt", now()), "foods");
        decided(adminUid, "food_approve", candidate, foodId);
        return view(mongo.findById(candidate.getObjectId("_id"), Document.class, COLLECTION));
    }

    @Transactional
    public void reject(String adminUid, String id) {
        Document candidate = claim(id, Update.update("status", "rejected").set("reviewedAt", now())
            .set("reviewedBy", adminUid));
        decided(adminUid, "food_reject", candidate, null);
    }

    /** Đổi món pending bằng [update] trong một lệnh; món đã duyệt/bỏ thì 409, không có thì 404. */
    private Document claim(String id, Update update) {
        if (id == null || !ObjectId.isValid(id)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "CANDIDATE_NOT_FOUND");
        }
        ObjectId oid = new ObjectId(id);
        Document d = mongo.findAndModify(Query.query(Criteria.where("_id").is(oid).and("status").is("pending")),
            update, FindAndModifyOptions.options().returnNew(true), Document.class, COLLECTION);
        if (d != null) {
            return d;
        }
        if (!mongo.exists(Query.query(Criteria.where("_id").is(oid)), COLLECTION)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "CANDIDATE_NOT_FOUND");
        }
        throw new ResponseStatusException(HttpStatus.CONFLICT, "CANDIDATE_REVIEWED");
    }

    /** Ghi admin_audit và bỏ các dòng đếm người dùng của món đã xử lý (không cần nữa). */
    private void decided(String adminUid, String action, Document candidate, ObjectId foodId) {
        Document a = new Document("uid", adminUid).append("action", action)
            .append("candidateId", candidate.getObjectId("_id")).append("at", now());
        if (foodId != null) {
            a.append("foodId", foodId);
        }
        mongo.insert(a, "admin_audit");
        mongo.remove(Query.query(Criteria.where("key").is(candidate.getString("key"))), USERS);
    }

    private Update base(String name) {
        return new Update().setOnInsert("nameVi", name.trim()).setOnInsert("firstSeenAt", now())
            .set("lastSeenAt", now());
    }

    /**
     * Ghi vào món pending có key này (tạo mới nếu chưa có). Người dùng lần đầu gặp món (upsert tạo được dòng
     * food_candidate_users) thì tăng userCount trong cùng lệnh. Món đã duyệt/bỏ: upsert đụng index unique key → bỏ qua.
     */
    private void record(ObjectId userId, String key, Update update) {
        if (key.isEmpty()) {
            return;
        }
        try {
            boolean newUser = mongo.upsert(Query.query(Criteria.where("key").is(key).and("userId").is(userId)),
                new Update().setOnInsert("at", now()), USERS).getUpsertedId() != null;
            if (newUser) {
                update.inc("userCount", 1);
            }
            Query pending = Query.query(Criteria.where("key").is(key).and("status").is("pending"));
            for (int attempt = 0; attempt < 2; attempt++) {
                try {
                    mongo.upsert(pending, update, COLLECTION);
                    return;
                } catch (DuplicateKeyException e) {
                    // Lần 1: request khác vừa tạo món này, thử lại sẽ cập nhật. Lần 2: món đã được duyệt/bỏ.
                }
            }
            if (newUser) {
                mongo.remove(Query.query(Criteria.where("key").is(key).and("userId").is(userId)), USERS);
            }
        } catch (RuntimeException e) {
            log.warn("Không ghi được food_candidates cho '{}': {}", key, e.getMessage());
        }
    }

    private Date now() {
        return Date.from(clock.instant());
    }

    static FoodCandidateDtos.CandidateView view(Document d) {
        List<RecognitionParser.Estimate> ai = d.getList("aiSamples", Document.class, List.of()).stream()
            .map(MealRecognitionService::estimateFrom).filter(e -> e != null).toList();
        List<Double> grams = d.getList("savedSamples", Document.class, List.of()).stream()
            .map(s -> s.get("grams") instanceof Number g ? g.doubleValue() : null).toList();
        int users = count(d, "userCount");
        Date last = d.getDate("lastSeenAt");
        return new FoodCandidateDtos.CandidateView(d.getObjectId("_id").toHexString(), d.getString("nameVi"),
            d.getString("status"), users, count(d, "sightings"), count(d, "saves"),
            FoodCandidateRules.suggestPer100g(ai), FoodCandidateRules.typicalGrams(grams),
            users >= FoodCandidateRules.SUGGEST_REVIEW_USERS, last == null ? null : last.toInstant(),
            d.get("foodId") instanceof ObjectId f ? f.toHexString() : null);
    }

    private static int count(Document d, String key) {
        return d.get(key) instanceof Number n ? n.intValue() : 0;
    }
}
