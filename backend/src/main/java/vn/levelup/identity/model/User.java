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
        Instant onboardingCompletedAt,
        Integer bodyFatPct,          // 5–50, người dùng tự chọn; số đo thật nằm ở body_measurements
        List<String> focusMuscles    // chest | back | shoulders | arms | abs | glutes | legs
    ) {}

    /**
     * followUp = true: vùng đau nhói báo sau buổi tập, đang được hỏi thăm mỗi ngày (PainRules).
     * reportedOn / lastAnswerOn là localDate "YYYY-MM-DD"; lastAnswer: gone | better | same | worse.
     */
    public record Injury(String bodyArea, String note, Boolean active, Instant reportedAt,
                         Boolean followUp, String reportedOn, String lastAnswer, String lastAnswerOn) {}

    /** time: giờ tập riêng "HH:mm" của ngày đó, null thì dùng giờ mặc định của khung (slot). */
    public record Availability(Integer weekday, String slot, String time) {
        public Availability(Integer weekday, String slot) {
            this(weekday, slot, null);
        }

        /** Giá trị đưa vào Week1PlanBuilder: giờ riêng nếu có, không thì tên khung. */
        public String slotOrTime() {
            return time != null ? time : slot;
        }
    }

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
