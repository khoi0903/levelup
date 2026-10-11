package vn.levelup.identity.dto;

import java.time.Instant;
import java.util.List;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

public record ProductConfig(
    boolean proEnabled, boolean referralEnabled,
    @Min(0) int coachFreePerDay, @Min(0) int coachProPerDay,
    @Min(0) int photosFreePerDay, @Min(0) int photosProPerDay,
    @Min(0) int referralInviteeDays, @NotNull List<@NotNull @Valid Milestone> referralMilestones,
    @Positive long monthlyPriceVnd, @Positive long yearlyPriceVnd, @Min(0) int trialDays,
    @Min(0) long version, String updatedBy, Instant updatedAt
) {
    public record Milestone(@Positive int friends, @Min(0) int days) {}

    @AssertTrue(message = "Mốc số bạn phải tăng dần")
    public boolean isMilestonesIncreasing() {
        if (referralMilestones == null) return true;
        int previous = 0;
        for (Milestone m : referralMilestones) {
            if (m == null || m.friends() <= previous) return false;
            previous = m.friends();
        }
        return true;
    }

    public static ProductConfig defaults() {
        return new ProductConfig(false, false, 10, 100, 3, 30, 7,
            List.of(new Milestone(1, 7), new Milestone(3, 30), new Milestone(10, 90)),
            49000, 399000, 7, 0, null, null);
    }
}
