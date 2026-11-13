package vn.levelup.nutrition.service;

import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.bson.Document;
import org.bson.types.ObjectId;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.io.ClassPathResource;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.Criteria;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;
import org.springframework.stereotype.Service;
import vn.levelup.nutrition.dto.MealDtos;
import vn.levelup.nutrition.rules.MealComments;

/**
 * Câu nhận xét sau khi lưu bữa, theo phong cách coach người dùng chọn. Câu mẫu ở docs/content/meal-comments.json;
 * câu "mo"/"ket" đã dùng lưu vào chính bữa ăn để 20 bữa gần nhất không lặp lại.
 */
@Service
public class MealCommentService {

    private static final Logger log = LoggerFactory.getLogger(MealCommentService.class);
    static final String RESOURCE = "content/meal-comments.json";
    static final int RECENT_MEALS = 20;

    private final MongoTemplate mongo;
    private final Document situations;

    public MealCommentService(MongoTemplate mongo) {
        this.mongo = mongo;
        this.situations = load();
    }

    private static Document load() {
        ClassPathResource resource = new ClassPathResource(RESOURCE);
        if (!resource.exists()) {
            log.warn("Không thấy {}, bỏ câu nhận xét bữa ăn", RESOURCE);
            return new Document();
        }
        try (InputStream in = resource.getInputStream()) {
            Document root = Document.parse(new String(in.readAllBytes(), StandardCharsets.UTF_8));
            return root.get("situations") instanceof Document d ? d : new Document();
        } catch (IOException e) {
            log.warn("Không đọc được {}: {}", RESOURCE, e.getMessage());
            return new Document();
        }
    }

    /**
     * Chọn câu cho bữa vừa lưu và ghi lại câu đã dùng vào bữa đó. Không có câu mẫu cho tình huống thì trả rỗng.
     * @param mealId bữa vừa lưu (seed chọn câu, cũng là chỗ ghi câu đã dùng)
     */
    public Optional<MealDtos.MealComment> comment(ObjectId userId, ObjectId mealId, String style,
                                                  MealComments.Input input, Map<String, String> vars) {
        String situation = MealComments.situation(input);
        String st = style == null ? "supportive" : style;
        Document byStyle = situations.get(situation) instanceof Document s
            ? (s.get(st) instanceof Document d ? d : s.get("supportive") instanceof Document d2 ? d2 : null)
            : null;
        if (byStyle == null) {
            return Optional.empty();
        }
        List<String> mo = strings(byStyle.get("mo"));
        List<String> ket = strings(byStyle.get("ket"));
        if (mo.isEmpty()) {
            return Optional.empty();
        }

        // Câu đã dùng ở các bữa gần nhất cùng tình huống và phong cách, mới nhất trước
        List<Document> recent = mongo.find(Query.query(Criteria.where("userId").is(userId)
                    .and("_id").ne(mealId).and("comment.situation").is(situation).and("comment.style").is(st))
                .with(Sort.by(Sort.Direction.DESC, "createdAt", "_id")).limit(RECENT_MEALS),
            Document.class, "meal_logs");
        List<Integer> usedMo = recent.stream().map(d -> index(d, "mo")).toList();
        List<Integer> usedKet = recent.stream().map(d -> index(d, "ket")).toList();
        long seed = mealId.hashCode();
        int m = MealComments.pick(mo.size(), usedMo, seed);
        int k = ket.isEmpty() ? -1 : MealComments.pick(ket.size(), usedKet, seed / 7);

        String text = MealComments.fill(mo.get(m), vars)
            + (k < 0 ? "" : " " + MealComments.fill(ket.get(k), vars));
        mongo.updateFirst(Query.query(Criteria.where("_id").is(mealId).and("userId").is(userId)),
            Update.update("comment", new Document("situation", situation).append("style", st)
                .append("mo", m).append("ket", k)), "meal_logs");
        return Optional.of(new MealDtos.MealComment(situation, text.trim()));
    }

    private static Integer index(Document meal, String key) {
        return meal.get("comment") instanceof Document c && c.get(key) instanceof Number n ? n.intValue() : null;
    }

    private static List<String> strings(Object value) {
        return value instanceof List<?> l ? l.stream().filter(String.class::isInstance).map(String.class::cast)
            .filter(s -> !s.isBlank()).toList() : List.of();
    }
}
