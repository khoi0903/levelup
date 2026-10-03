package vn.levelup.reviews;

import java.time.Instant;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import vn.levelup.plans.PlanView;

/** Request và response của /reviews. */
public final class ReviewViews {

    private ReviewViews() {}

    /**
     * Tổng kết tuần kèm kế hoạch nháp tuần sau.
     * recommendation: increase | keep | decrease. decision: pending | accepted | adjusted | dismissed.
     * source: "ai" hoặc "rules" (câu mẫu khi không có AI).
     */
    public record ReviewView(String id, String weekStart, int sessionsDone, int sessionsTarget, int completionPct,
                             int totalMinutes, Double avgRpe, String recommendation, String win, List<Win> wins,
                             String improvement, String nextWeekSummary, Double weightChangeKg,
                             String decision, String source, Instant generatedAt, PlanView plan) {}

    /** type: pr (kỷ lục mới). */
    public record Win(String type, String label) {}

    /** decision: accepted (dùng nguyên kế hoạch nháp) hoặc adjusted (kèm adjustments). */
    public record DecisionRequest(
        @NotNull @Pattern(regexp = "accepted|adjusted") String decision,
        @Valid Adjustments adjustments
    ) {}

    public record Adjustments(
        @Min(1) @Max(7) Integer sessionsPerWeek,
        @Min(5) @Max(90) Integer sessionMinutes
    ) {}
}
