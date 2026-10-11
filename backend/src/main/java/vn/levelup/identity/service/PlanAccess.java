package vn.levelup.identity.service;

import java.time.Clock;
import java.time.Instant;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import vn.levelup.identity.dto.ProductConfig;
import vn.levelup.identity.dto.SubscriptionView;
import vn.levelup.identity.model.User;

@Service
public class PlanAccess {
    private final ProductConfigService configs;
    private final Clock clock;
    private final int legacyCoach;
    private final int legacyPhotos;
    public PlanAccess(ProductConfigService configs, Clock clock,
            @Value("${levelup.coach.daily-limit:30}") int legacyCoach,
            @Value("${levelup.nutrition.daily-photo-limit:10}") int legacyPhotos) {
        this.configs = configs; this.clock = clock; this.legacyCoach = legacyCoach; this.legacyPhotos = legacyPhotos;
    }
    public boolean isPro(User user, Instant now) {
        return user.plan() != null && "pro".equals(user.plan().tier()) && user.plan().expiresAt() != null
            && user.plan().expiresAt().isAfter(now);
    }
    public SubscriptionView subscription(User user) {
        ProductConfig c = configs.get();
        boolean pro = isPro(user, clock.instant());
        return new SubscriptionView(c.proEnabled(), pro ? "pro" : "free",
            user.plan() == null ? null : user.plan().expiresAt(),
            new SubscriptionView.Limits(c.proEnabled() ? (pro ? c.coachProPerDay() : c.coachFreePerDay()) : legacyCoach,
                c.proEnabled() ? (pro ? c.photosProPerDay() : c.photosFreePerDay()) : legacyPhotos));
    }
    public int coachLimit(User user) { return subscription(user).limits().coachPerDay(); }
    public int photoLimit(User user) { return subscription(user).limits().photosPerDay(); }
}
