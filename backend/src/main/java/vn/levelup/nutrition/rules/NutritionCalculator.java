package vn.levelup.nutrition.rules;

import java.time.LocalDate;
import vn.levelup.identity.model.User;


/**
 * Mục tiêu calo và macro theo công thức Mifflin-St Jeor, mức vận động nhẹ (x1.375).
 * Mức sàn bắt buộc: 1200 kcal, nam 1500 kcal (xem AGENTS.md).
 */
public final class NutritionCalculator {

    static final double ACTIVITY_LIGHT = 1.375;
    static final int FLOOR_DEFAULT = 1200;
    static final int FLOOR_MALE = 1500;
    static final int DEFAULT_AGE = 25;

    private NutritionCalculator() {}

    public static User.NutritionTarget compute(String gender, Integer birthYear, double heightCm,
                                               double weightKg, String goal, LocalDate today) {
        int age = birthYear == null ? DEFAULT_AGE : Math.max(14, today.getYear() - birthYear);
        double base = 10 * weightKg + 6.25 * heightCm - 5 * age;
        double bmr = switch (gender == null ? "other" : gender) {
            case "male" -> base + 5;
            case "female" -> base - 161;
            default -> base - 78;           // trung bình hai công thức
        };
        double tdee = bmr * ACTIVITY_LIGHT;

        double kcal = switch (goal) {
            case "lose_fat" -> tdee - Math.min(500, tdee * 0.2);   // thâm hụt vừa phải
            case "build_muscle" -> tdee + 250;
            default -> tdee;
        };
        int floor = "male".equals(gender) ? FLOOR_MALE : FLOOR_DEFAULT;
        int kcalTarget = (int) Math.round(Math.max(floor, kcal) / 10.0) * 10;

        double proteinPerKg = switch (goal) {
            case "lose_fat", "build_muscle" -> 1.6;
            default -> 1.2;
        };
        int protein = (int) Math.round(weightKg * proteinPerKg);
        int fat = (int) Math.round(kcalTarget * 0.25 / 9);
        int carbs = Math.max(0, (int) Math.round((kcalTarget - protein * 4 - fat * 9) / 4.0));
        int water = (int) Math.round(weightKg * 35 / 250.0) * 250;   // làm tròn theo ly 250 ml

        return new User.NutritionTarget(today.toString(), kcalTarget, protein, carbs, fat, water,
            "mifflin_st_jeor");
    }
}
