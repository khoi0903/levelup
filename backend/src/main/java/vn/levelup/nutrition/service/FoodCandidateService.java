package vn.levelup.nutrition.service;

import java.time.Clock;
import java.util.Date;
import java.util.List;

import org.bson.Document;
import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.nutrition.dto.FoodCandidateDtos;
import vn.levelup.nutrition.rules.FoodCandidateRules;
import vn.levelup.nutrition.rules.RecognitionParser;
import vn.levelup.nutrition.rules.VietText;

/**
 * Kho chờ food_candidates: món chưa có trong kho foods mà AI nhận ra hoặc người dùng nhập tay.
 * Gom theo tên đã chuẩn hóa để sau này có dữ liệu món ăn; AI không ghi vào foods, chỉ Admin duyệt mới thêm vào kho.
 * Lỗi ghi kho chờ không bao giờ làm hỏng việc nhận diện hay lưu bữa.
 */
@Service
public class FoodCandidateService {

    private static final Logger log = LoggerFactory.getLogger(FoodCandidateService.class);
    static final String COLLECTION = "food_candidates";
    static final int AI_SAMPLES = 20;
    static final int SAVED_SAMPLES = 50;

    private final MongoTemplate mongo;
    private final Clock clock;

    public FoodCandidateService(MongoTemplate mongo, Clock clock) {
        this.mongo = mongo;
        this.clock = clock;
    }

    /** AI nhận ra món không có trong kho. */
    public void recordRecognized(ObjectId userId, RecognitionParser.Dish dish) {
        Update u = base(userId, dish.nameVi()).inc("sightings", 1);
        if (dish.per100g() != null) {
            RecognitionParser.Estimate e = dish.per100g();
            u.push("aiSamples").slice(-AI_SAMPLES).each(new Document("kcal", e.kcal()).append("proteinG", e.proteinG())
                .append("carbsG", e.carbsG()).append("fatG", e.fatG()).append("at", now()));
        }
        upsert(dish.nameVi(), u);
    }

    /** Người dùng lưu một món không có foodId (từ ảnh hoặc nhập tay): số liệu người thật đã xem/sửa. */
    public void recordSaved(ObjectId userId, String name, Double grams, double kcal, double proteinG, double carbsG,
                            double fatG, boolean fromPhoto) {
        Document sample = new Document("userId", userId).append("kcal", kcal).append("proteinG", proteinG)
            .append("carbsG", carbsG).append("fatG", fatG).append("fromPhoto", fromPhoto).append("at", now());
        if (grams != null) {
            sample.append("grams", grams);
        }
        upsert(name, base(userId, name).inc("saves", 1).push("savedSamples").slice(-SAVED_SAMPLES).each(sample));
    }

    public List<FoodCandidateDtos.CandidateView> list(String status, int limit) {
        Query q = Query.query(Criteria.where("status").is(status))
            .with(Sort.by(Sort.Direction.DESC, "userCount", "lastSeenAt")).limit(limit);
        return mongo.find(q, Document.class, COLLECTION).stream().map(FoodCandidateService::view).toList();
    }

    /** Thêm món vào kho foods (source "ai", đã duyệt) và đánh dấu món chờ là approved. */
    public FoodCandidateDtos.CandidateView approve(String adminUid, String id, FoodCandidateDtos.ApproveRequest r) {
        Document candidate = pending(id);
        String searchName = VietText.normalize(r.nameVi());
        if (searchName.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_NAME");
        }
        if (mongo.exists(Query.query(Criteria.where("searchName").is(searchName)), "foods")) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "FOOD_EXISTS");
        }
        String original = candidate.getString("nameVi");
        List<String> aliases = original != null && !VietText.normalize(original).equals(searchName)
            ? List.of(VietText.normalize(original)) : List.of();
        ObjectId foodId = new ObjectId();
        mongo.insert(new Document("_id", foodId).append("nameVi", r.nameVi().trim()).append("searchName", searchName)
            .append("aliases", aliases).append("category", r.category()).append("servingDesc", r.servingDesc().trim())
            .append("servingGrams", r.servingGrams()).append("kcal", r.kcal()).append("proteinG", r.proteinG())
            .append("carbsG", r.carbsG()).append("fatG", r.fatG()).append("source", "ai").append("verified", true)
            .append("createdAt", now()), "foods");
        mongo.updateFirst(Query.query(Criteria.where("_id").is(candidate.getObjectId("_id"))),
            Update.update("status", "approved").set("foodId", foodId).set("reviewedAt", now())
                .set("reviewedBy", adminUid), COLLECTION);
        audit(adminUid, "food_approve", candidate.getObjectId("_id"), foodId);
        return view(mongo.findById(candidate.getObjectId("_id"), Document.class, COLLECTION));
    }

    public void reject(String adminUid, String id) {
        Document candidate = pending(id);
        mongo.updateFirst(Query.query(Criteria.where("_id").is(candidate.getObjectId("_id"))),
            Update.update("status", "rejected").set("reviewedAt", now()).set("reviewedBy", adminUid), COLLECTION);
        audit(adminUid, "food_reject", candidate.getObjectId("_id"), null);
    }

    private Document pending(String id) {
        if (id == null || !ObjectId.isValid(id)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "CANDIDATE_NOT_FOUND");
        }
        Document d = mongo.findById(new ObjectId(id), Document.class, COLLECTION);
        if (d == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "CANDIDATE_NOT_FOUND");
        }
        if (!"pending".equals(d.getString("status"))) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "CANDIDATE_REVIEWED");
        }
        return d;
    }

    private Update base(ObjectId userId, String name) {
        return new Update().setOnInsert("nameVi", name.trim()).setOnInsert("status", "pending")
            .setOnInsert("firstSeenAt", now()).set("lastSeenAt", now()).addToSet("userIds", userId);
    }

    /** Upsert theo key; hai request cùng tạo một món thì lần thứ hai cập nhật bản đã có. */
    private void upsert(String name, Update update) {
        String key = VietText.normalize(name);
        if (key.isEmpty()) {
            return;
        }
        Query q = Query.query(Criteria.where("key").is(key));
        try {
            for (int i = 0; i < 2; i++) {
                try {
                    mongo.upsert(q, update, COLLECTION);
                    break;
                } catch (DuplicateKeyException race) {
                    // request khác vừa tạo món này: thử lại sẽ cập nhật
                }
            }
            // userCount để sắp xếp: số người dùng khác nhau
            Document d = mongo.findOne(q, Document.class, COLLECTION);
            if (d != null) {
                mongo.updateFirst(q, Update.update("userCount", d.getList("userIds", Object.class, List.of()).size()),
                    COLLECTION);
            }
        } catch (RuntimeException e) {
            log.warn("Không ghi được food_candidates cho '{}': {}", key, e.getMessage());
        }
    }

    private void audit(String adminUid, String action, ObjectId candidateId, ObjectId foodId) {
        Document a = new Document("uid", adminUid).append("action", action).append("candidateId", candidateId)
            .append("at", now());
        if (foodId != null) {
            a.append("foodId", foodId);
        }
        mongo.insert(a, "admin_audit");
    }

    private Date now() {
        return Date.from(clock.instant());
    }

    static FoodCandidateDtos.CandidateView view(Document d) {
        List<FoodCandidateRules.Saved> saved = d.getList("savedSamples", Document.class, List.of()).stream()
            .map(s -> new FoodCandidateRules.Saved(s.get("grams") instanceof Number g ? g.doubleValue() : null,
                num(s, "kcal"), num(s, "proteinG"), num(s, "carbsG"), num(s, "fatG")))
            .toList();
        List<RecognitionParser.Estimate> ai = d.getList("aiSamples", Document.class, List.of()).stream()
            .map(s -> new RecognitionParser.Estimate(num(s, "kcal"), num(s, "proteinG"), num(s, "carbsG"),
                num(s, "fatG")))
            .toList();
        RecognitionParser.Estimate e = FoodCandidateRules.suggestPer100g(saved, ai);
        int users = d.getList("userIds", Object.class, List.of()).size();
        Date last = d.getDate("lastSeenAt");
        return new FoodCandidateDtos.CandidateView(d.getObjectId("_id").toHexString(), d.getString("nameVi"),
            d.getString("status"), users, (int) num(d, "sightings"), (int) num(d, "saves"),
            e == null ? null : new FoodCandidateDtos.Per100g(e.kcal(), e.proteinG(), e.carbsG(), e.fatG()),
            FoodCandidateRules.typicalGrams(saved), users >= FoodCandidateRules.SUGGEST_REVIEW_USERS,
            last == null ? null : last.toInstant(),
            d.get("foodId") instanceof ObjectId f ? f.toHexString() : null);
    }

    private static double num(Document d, String key) {
        return d.get(key) instanceof Number n ? n.doubleValue() : 0;
    }
}
