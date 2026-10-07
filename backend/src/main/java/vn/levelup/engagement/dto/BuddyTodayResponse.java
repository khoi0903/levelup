package vn.levelup.engagement.dto;

import java.time.Instant;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * GET /buddies/today. Mặc định chỉ có trạng thái tập và streak của buddy;
 * shared chỉ xuất hiện khi buddy tự bật chia sẻ từng mục (users.sharing).
 */
public record BuddyTodayResponse(
    String pairId,
    Instant since,
    Integer sharedStreakWeeks,
    Buddy buddy,
    MyActions myActionsToday,
    @JsonInclude(JsonInclude.Include.NON_NULL) Shared shared
) {
    /**
     * localDate: hôm nay theo giờ của buddy. status: done | planned | rest | none.
     * scheduledTime, sessionTitle chỉ có khi status = planned.
     */
    public record Buddy(
        String displayName,
        String localDate,
        String status,
        @JsonInclude(JsonInclude.Include.NON_NULL) String scheduledTime,
        @JsonInclude(JsonInclude.Include.NON_NULL) String sessionTitle,
        Week week,
        int streakWeeks
    ) {}

    public record Week(String weekStart, int completedSessions, int targetSessions) {}

    /** Người gọi đã nhắc / cổ vũ hôm nay chưa (theo ngày của người gọi). */
    public record MyActions(boolean nudged, boolean cheered) {}

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record Shared(Double weightKg, Measurements measurements, Integer mealsKcalToday) {}

    @JsonInclude(JsonInclude.Include.NON_NULL)
    public record Measurements(String measuredOn, Double waistCm, Double hipCm, Double chestCm, Double armCm) {}
}
