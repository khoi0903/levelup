package vn.levelup.nutrition.config;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.index.Index;

/** Tạo sẵn food_candidates (cả trên database đã chạy từ trước, chưa chạy lại init.js). */
@Configuration
public class NutritionIndexes {
    private final MongoTemplate mongo;
    public NutritionIndexes(MongoTemplate mongo) { this.mongo = mongo; }
    @PostConstruct
    void initialize() {
        if (!mongo.collectionExists("food_candidates")) mongo.createCollection("food_candidates");
        mongo.indexOps("food_candidates").ensureIndex(new Index().on("key", Sort.Direction.ASC).unique());
        mongo.indexOps("food_candidates").ensureIndex(new Index().on("status", Sort.Direction.ASC)
            .on("userCount", Sort.Direction.DESC).on("lastSeenAt", Sort.Direction.DESC));
    }
}
