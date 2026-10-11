package vn.levelup.identity.config;

import jakarta.annotation.PostConstruct;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.index.Index;
import org.springframework.data.mongodb.core.index.PartialIndexFilter;
import org.springframework.data.mongodb.core.query.Criteria;

@Configuration
public class ProductIndexes {
    private final MongoTemplate mongo;
    public ProductIndexes(MongoTemplate mongo) { this.mongo = mongo; }
    @PostConstruct
    void initialize() {
        // Pre-create collections outside transactions, including existing installations.
        for (String name : new String[]{"app_config", "billing_events", "referrals", "referral_rewards", "admin_audit"})
            if (!mongo.collectionExists(name)) mongo.createCollection(name);
        mongo.indexOps("billing_events").ensureIndex(new Index().on("eventId", Sort.Direction.ASC).unique());
        mongo.indexOps("referrals").ensureIndex(new Index().on("inviteeId", Sort.Direction.ASC).unique());
        mongo.indexOps("referrals").ensureIndex(new Index().on("referrerId", Sort.Direction.ASC).on("status", Sort.Direction.ASC));
        mongo.indexOps("referral_rewards").ensureIndex(new Index().on("referrerId", Sort.Direction.ASC)
            .on("friends", Sort.Direction.ASC).unique());
        mongo.indexOps("users").ensureIndex(new Index().on("referralCode", Sort.Direction.ASC).unique()
            .partial(PartialIndexFilter.of(Criteria.where("referralCode").type(2))));
    }
}
