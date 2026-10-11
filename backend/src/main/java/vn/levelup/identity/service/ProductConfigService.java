package vn.levelup.identity.service;

import java.time.Clock;
import java.util.Date;
import org.bson.Document;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.data.mongodb.core.query.*;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.server.ResponseStatusException;
import vn.levelup.identity.dto.ProductConfig;

@Service
public class ProductConfigService {
    private final MongoTemplate mongo;
    private final Clock clock;
    private ProductConfig cached;
    private long cachedAt;
    private static final long CACHE_NANOS = java.time.Duration.ofSeconds(5).toNanos();
    public ProductConfigService(MongoTemplate mongo, Clock clock) { this.mongo = mongo; this.clock = clock; }

    // Short cache for ordinary reads; transactions use their own consistent Mongo snapshot.
    public ProductConfig get() {
        if (TransactionSynchronizationManager.isActualTransactionActive()) return read();
        synchronized (this) {
            if (cached == null || System.nanoTime() - cachedAt >= CACHE_NANOS) {
                cached = read();
                cachedAt = System.nanoTime();
            }
            return cached;
        }
    }
    private ProductConfig read() {
        ProductConfig config = mongo.findById("product", ProductConfig.class, "app_config");
        return config == null ? ProductConfig.defaults() : config;
    }
    public synchronized void invalidate() { cached = null; }

    @Transactional
    public ProductConfig update(String uid, ProductConfig input) {
        ProductConfig before = get();
        if (before.version() != input.version())
            throw new ResponseStatusException(HttpStatus.CONFLICT, "CONFIG_CHANGED");
        ProductConfig after = new ProductConfig(input.proEnabled(), input.referralEnabled(),
            input.coachFreePerDay(), input.coachProPerDay(), input.photosFreePerDay(), input.photosProPerDay(),
            input.referralInviteeDays(), input.referralMilestones(), input.monthlyPriceVnd(), input.yearlyPriceVnd(),
            input.trialDays(), before.version() + 1, uid, clock.instant());
        Document value = new Document();
        mongo.getConverter().write(after, value);
        value.remove("_class");
        value.put("_id", "product");
        // Transaction conflict detection also protects concurrent saves of the same version.
        mongo.save(value, "app_config");
        Document oldValue = new Document();
        mongo.getConverter().write(before, oldValue);
        mongo.insert(new Document("uid", uid).append("before", oldValue).append("after", value)
            .append("at", Date.from(clock.instant())), "admin_audit");
        TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
            @Override public void afterCommit() { invalidate(); }
        });
        return after;
    }
}
