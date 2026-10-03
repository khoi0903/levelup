package vn.levelup.users;

import java.time.Instant;
import java.util.List;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

/**
 * Collection "users". Tên trường khớp validator trong mongo/init.js.
 * Mới khai báo các phần màn hình chính cần; các phần nhúng khác (injuries, devices,
 * coachMemory...) thêm dần theo từng sprint.
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
    Streak streak,
    Instant createdAt,
    Instant lastActiveAt
) {
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

    public record Streak(
        Integer currentWeeks,
        Integer bestWeeks,
        Integer freezesAvailable,
        String lastClosedWeek
    ) {}
}
