package vn.levelup.engagement.dto;
import java.util.List;
import java.time.Instant;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import vn.levelup.identity.dto.ProductConfig.Milestone;
public final class ReferralDtos {
    private ReferralDtos() {}
    public record Redeem(@NotBlank @Size(max = 32) String code) {}
    public record Reward(int friends, int days, Instant at) {}
    public record View(String code, String link, long successfulCount, Milestone nextMilestone,
                       List<Reward> rewardsEarned, List<Milestone> milestones) {}
}
