package vn.levelup.identity.model;

import java.time.Instant;
import java.util.List;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Collection "users". Tên trường khớp validator trong mongo/init.js.
 * Các phần nhúng khác (devices, coachMemory, reengagement...) thêm dần theo từng sprint.
 * Ghi vào users bằng MongoTemplate ($set từng trường), không save() cả record,
 * để không xóa mất các trường record này chưa khai báo.
 */
@Document("users")
public record User(
    @Id String id,
    String authUid,
    String email,
    String displayName,
    String timezone,
    String locale,
    Profile profile,
    List<Injury> injuries,
    List<Availability> availability,
    List<NutritionTarget> nutritionTargets,
    Streak streak,
    Instant createdAt,
    Instant lastActiveAt,
    Plan plan,
    String referralCode
) {
    public record Plan(String tier, String source, Instant expiresAt, Instant updatedAt) {}

    public User(String id, String authUid, String email, String displayName, String timezone, String locale,
                Profile profile, List<Injury> injuries, List<Availability> availability,
                List<NutritionTarget> nutritionTargets, Streak streak, Instant createdAt, Instant lastActiveAt) {
        this(id, authUid, email, displayName, timezone, locale, profile, injuries, availability,
            nutritionTargets, streak, createdAt, lastActiveAt, null, null);
    }

    public record Profile(
        String goal,             // lose_fat | build_muscle | get_healthier | maintain
        String gender,           // male | female | other
        Integer birthYear,
        Double heightCm,
        Double startWeightKg,
        Double goalWeightKg,
        String experience,       // beginner | intermediate | regular
        String location,         // home | gym | outdoor
        Integer sessionMinutes,
        String coachStyle,       // strict | supportive | funny
        List<String> motivationReasons,
        String motivationText,
        List<String> equipment,
        Instant onboardingCompletedAt
    ) {}

    public record Injury(String bodyArea, String note, Boolean active, Instant reportedAt) {}

    public record Availability(Integer weekday, String slot) {}

    public record NutritionTarget(
        String effectiveFrom, Integer kcal, Integer proteinG, Integer carbsG, Integer fatG,
        Integer waterMl, String method) {}

    public record Streak(
        Integer currentWeeks,
        Integer bestWeeks,
        Integer freezesAvailable,
        String lastClosedWeek
    ) {}
}
