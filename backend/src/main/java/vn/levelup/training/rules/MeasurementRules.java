package vn.levelup.training.rules;

import java.time.LocalDate;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Stream;
import vn.levelup.training.dto.MeasurementDtos;

/** Luật đo cơ thể không đọc hay ghi database, để unit test. */
public final class MeasurementRules {

    /** Huy hiệu giảm 1 cm vòng eo so với lần đo đầu, khớp mongo/seed/achievements.json. */
    public static final String WAIST_CODE = "body_waist_cm_1";
    static final double WAIST_DROP_CM = 1.0;
    static final int MAX_BACKFILL_DAYS = 365;

    private MeasurementRules() {}

    public static boolean hasAnyValue(MeasurementDtos.MeasurementRequest r) {
        return Stream.of(r.weightKg(), r.waistCm(), r.hipCm(), r.chestCm(), r.armCm(), r.bodyFatPct())
            .anyMatch(v -> v != null);
    }

    /** Ngày đo hợp lệ: không sau hôm nay, không cũ quá một năm. */
    public static boolean validDate(LocalDate measuredOn, LocalDate today) {
        return !measuredOn.isAfter(today) && !measuredOn.isBefore(today.minusDays(MAX_BACKFILL_DAYS));
    }

    /** Vòng eo mới nhất giảm từ 1 cm so với lần đo đầu và người dùng chưa có huy hiệu. */
    public static Optional<String> waistAchievement(Double firstWaistCm, Double latestWaistCm, Set<String> owned) {
        if (firstWaistCm == null || latestWaistCm == null || owned.contains(WAIST_CODE)) {
            return Optional.empty();
        }
        // làm tròn 0.01 cm để 80.0 - 79.0 không lệch vì số thực
        double drop = Math.round((firstWaistCm - latestWaistCm) * 100) / 100.0;
        return drop >= WAIST_DROP_CM ? Optional.of(WAIST_CODE) : Optional.empty();
    }
}
