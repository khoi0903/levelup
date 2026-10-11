package vn.levelup.identity.dto;
import java.time.Instant;
public record SubscriptionView(boolean enabled, String tier, Instant expiresAt, Limits limits) {
    public record Limits(int coachPerDay, int photosPerDay) {}
}
