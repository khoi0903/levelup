package vn.levelup.nutrition.rules;

/** Chỉ số cơ thể cho GET /me/body: BMI, phân loại, ước tính tỉ lệ mỡ. Không đọc hay ghi database. */
public final class BodyRules {

    public static final int BODY_FAT_MIN = 5;
    public static final int BODY_FAT_MAX = 50;

    private BodyRules() {}

    /** BMI làm tròn 1 chữ số; null khi thiếu chiều cao hoặc cân nặng. */
    public static Double bmi(Double heightCm, Double weightKg) {
        if (heightCm == null || weightKg == null || heightCm <= 0 || weightKg <= 0) {
            return null;
        }
        double m = heightCm / 100.0;
        return NutritionRules.round1(weightKg / (m * m));
    }

    /** Ngưỡng WHO cho người châu Á: <18.5 thiếu cân, <23 bình thường, <25 thừa cân, từ 25 béo phì. */
    public static String bmiCategory(Double bmi) {
        if (bmi == null) {
            return null;
        }
        if (bmi < 18.5) {
            return "underweight";
        }
        if (bmi < 23) {
            return "normal";
        }
        return bmi < 25 ? "overweight" : "obese";
    }

    /**
     * Ước tính tỉ lệ mỡ theo Deurenberg: 1.2·BMI + 0.23·tuổi − 10.8·giới − 5.4 (nam = 1, nữ/khác = 0),
     * làm tròn và giới hạn trong 5–50. null khi chưa có BMI.
     */
    public static Integer estimateBodyFatPct(Double bmi, int age, String gender) {
        if (bmi == null) {
            return null;
        }
        double sex = "male".equals(gender) ? 1 : 0;
        return clampBodyFat(1.2 * bmi + 0.23 * age - 10.8 * sex - 5.4);
    }

    public static int clampBodyFat(double pct) {
        return (int) Math.max(BODY_FAT_MIN, Math.min(BODY_FAT_MAX, Math.round(pct)));
    }

    /** Tỉ lệ mỡ hiển thị và có phải số ước tính không. */
    public record BodyFat(Integer pct, boolean estimated) {}

    /** Ưu tiên số đo mới nhất, rồi số người dùng tự chọn trong hồ sơ, cuối cùng mới ước tính. */
    public static BodyFat bodyFat(Double measuredPct, Integer profilePct, Double bmi, int age, String gender) {
        if (measuredPct != null) {
            return new BodyFat((int) Math.round(measuredPct), false);
        }
        if (profilePct != null) {
            return new BodyFat(profilePct, false);
        }
        Integer estimate = estimateBodyFatPct(bmi, age, gender);
        return new BodyFat(estimate, estimate != null);
    }
}
