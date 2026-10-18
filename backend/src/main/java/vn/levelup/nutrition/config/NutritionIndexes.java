package vn.levelup.nutrition.config;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.index.Index;

/**
 * Index của food_candidates, food_candidate_users (cả trên database đã chạy từ trước, chưa chạy lại init.js).
 * Tạo index cũng tạo collection, ngoài transaction.
 */
@Configuration
public class NutritionIndexes {
    private final MongoTemplate mongo;
    public NutritionIndexes(MongoTemplate mongo) { this.mongo = mongo; }
    @PostConstruct
    void initialize() {
        mongo.indexOps("food_candidates").ensureIndex(new Index().on("key", Sort.Direction.ASC).unique());
        mongo.indexOps("food_candidates").ensureIndex(new Index().on("status", Sort.Direction.ASC)
            .on("userCount", Sort.Direction.DESC).on("lastSeenAt", Sort.Direction.DESC));
        // userId đứng trước: một index phục vụ cả đếm (key, userId) lẫn xoá tài khoản theo userId
        mongo.indexOps("food_candidate_users").ensureIndex(new Index().on("userId", Sort.Direction.ASC)
            .on("key", Sort.Direction.ASC).unique());
    }
}
