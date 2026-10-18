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
 * Kho chờ food_candidates: món chưa có trong kho foods mà AI nhận ra trong ảnh.
 * Gom theo tên đã chuẩn hóa để sau này có dữ liệu món ăn; AI không ghi vào foods, chỉ Admin duyệt mới thêm vào kho.
 * Lỗi ghi kho chờ không bao giờ làm hỏng việc nhận diện hay lưu bữa.
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
    private final Clock clock;

    public FoodCandidateService(MongoTemplate mongo, Clock clock) {
        this.mongo = mongo;
        this.clock = clock;
    }

    /** AI nhận ra món không có trong kho. */
    public void recordRecognized(ObjectId userId, RecognitionParser.Dish dish) {
        Update u = base(dish.nameVi()).inc("sightings", 1);
        if (dish.per100g() != null) {
            RecognitionParser.Estimate e = dish.per100g();
            u.push("aiSamples").slice(-AI_SAMPLES).each(new Document("kcal", e.kcal()).append("proteinG", e.proteinG())
                .append("carbsG", e.carbsG()).append("fatG", e.fatG()).append("at", now()));
        }
        upsert(userId, dish.nameVi(), u);
    }

    /** Người dùng lưu món ảnh không có foodId: số liệu người thật đã xem/sửa (không lưu userId trong mẫu). */
    public void recordSaved(ObjectId userId, String name, Double grams, double kcal, double proteinG, double carbsG,
                            double fatG, boolean fromPhoto) {
        Document sample = new Document("kcal", kcal).append("proteinG", proteinG)
            .append("carbsG", carbsG).append("fatG", fatG).append("fromPhoto", fromPhoto).append("at", now());
        if (grams != null) {
            sample.append("grams", grams);
        }
        upsert(userId, name, base(name).inc("saves", 1).push("savedSamples").slice(-SAVED_SAMPLES).each(sample));
    }

    public List<FoodCandidateDtos.CandidateView> list(String status, int limit) {
        Query q = Query.query(Criteria.where("status").is(status))
            .with(Sort.by(Sort.Direction.DESC, "userCount", "lastSeenAt")).limit(limit);
        return mongo.find(q, Document.class, COLLECTION).stream().map(FoodCandidateService::view).toList();
    }

    /** Thêm món vào kho foods (source "ai", đã duyệt) và đánh dấu món chờ là approved. */
    public FoodCandidateDtos.CandidateView approve(String adminUid, String id, FoodCandidateDtos.ApproveRequest r) {
        String searchName = VietText.normalize(r.nameVi());
        if (searchName.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "INVALID_NAME");
        }
        // Giành món trong một lệnh: hai lần bấm duyệt cùng lúc chỉ một lần thêm vào kho
        Document candidate = claim(id, "approving");
        ObjectId candidateId = candidate.getObjectId("_id");
        String original = candidate.getString("nameVi");
        List<String> aliases = original != null && !VietText.normalize(original).equals(searchName)
            ? List.of(VietText.normalize(original)) : List.of();
        ObjectId foodId = new ObjectId();
        try {
            if (mongo.exists(Query.query(Criteria.where("searchName").is(searchName)), "foods")) {
                throw new ResponseStatusException(HttpStatus.CONFLICT, "FOOD_EXISTS");
            }
            mongo.insert(new Document("_id", foodId).append("nameVi", r.nameVi().trim())
                .append("searchName", searchName).append("aliases", aliases).append("category", r.category())
                .append("servingDesc", r.servingDesc().trim()).append("servingGrams", r.servingGrams())
                .append("kcal", r.kcal()).append("proteinG", r.proteinG()).append("carbsG", r.carbsG())
                .append("fatG", r.fatG()).append("source", "ai").append("verified", true)
                .append("createdAt", now()), "foods");
        } catch (RuntimeException e) {
            // Thêm vào kho lỗi: trả món về chờ duyệt để Admin thử lại
            mongo.updateFirst(Query.query(Criteria.where("_id").is(candidateId)), Update.update("status", "pending"),
                COLLECTION);
            throw e;
        }
        mongo.updateFirst(Query.query(Criteria.where("_id").is(candidateId)),
            Update.update("status", "approved").set("foodId", foodId).set("reviewedAt", now())
                .set("reviewedBy", adminUid), COLLECTION);
        audit(adminUid, "food_approve", candidateId, foodId);
        return view(mongo.findById(candidateId, Document.class, COLLECTION));
    }

    public void reject(String adminUid, String id) {
        Document candidate = claim(id, "rejected");
        mongo.updateFirst(Query.query(Criteria.where("_id").is(candidate.getObjectId("_id"))),
            Update.update("reviewedAt", now()).set("reviewedBy", adminUid), COLLECTION);
        audit(adminUid, "food_reject", candidate.getObjectId("_id"), null);
    }

    /** Đổi pending sang [status] trong một lệnh; món đã duyệt/bỏ hoặc đang được duyệt thì 409. */
    private Document claim(String id, String status) {
        if (id == null || !ObjectId.isValid(id)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "CANDIDATE_NOT_FOUND");
        }
        Query byId = Query.query(Criteria.where("_id").is(new ObjectId(id)));
        Document d = mongo.findAndModify(Query.query(Criteria.where("_id").is(new ObjectId(id)).and("status")
            .is("pending")), Update.update("status", status), Document.class, COLLECTION);
        if (d != null) {
            return d;
        }
        if (!mongo.exists(byId, COLLECTION)) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "CANDIDATE_NOT_FOUND");
        }
        throw new ResponseStatusException(HttpStatus.CONFLICT, "CANDIDATE_REVIEWED");
    }

    private Update base(String name) {
        return new Update().setOnInsert("nameVi", name.trim()).setOnInsert("status", "pending")
            .setOnInsert("userCount", 0).setOnInsert("firstSeenAt", now()).set("lastSeenAt", now());
    }

    /**
     * Upsert theo key; hai request cùng tạo một món thì lần thứ hai cập nhật bản đã có.
     * Người dùng lần đầu gặp món này (chèn được dòng food_candidate_users) thì tăng userCount.
     */
    private void upsert(ObjectId userId, String name, Update update) {
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
            try {
                mongo.insert(new Document("key", key).append("userId", userId).append("at", now()), USERS);
                mongo.updateFirst(q, new Update().inc("userCount", 1), COLLECTION);
            } catch (DuplicateKeyException seen) {
                // người dùng này đã được đếm cho món này
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
        int users = (int) num(d, "userCount");
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
