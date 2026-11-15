package vn.levelup.nutrition.dto;

import java.util.List;

/**
 * GET /me/body: chỉ số cơ thể. Trường nào không tính được thì null.
 * weightKg: số cân mới nhất trong body_measurements, chưa cân lần nào thì cân lúc onboarding.
 * bmiCategory: underweight | normal | overweight | obese (ngưỡng châu Á 18.5 / 23 / 25).
 * bodyFatPct: số đo mới nhất, không có thì số tự chọn trong hồ sơ, không có nữa thì ước tính
 * (bodyFatEstimated = true). targetKcal, macro, waterMl: mục tiêu đang áp dụng, giống GET /nutrition/today.
 * waistCm, hipCm, chestCm, armCm: số đo vòng mới nhất (null nếu chưa đo) để app vẽ hình sát người thật hơn.
 */
public record BodyView(
    String gender,
    Integer age,
    Double heightCm,
    Double weightKg,
    Double bmi,
    String bmiCategory,
    Integer bodyFatPct,
    boolean bodyFatEstimated,
    Integer bmr,
    Integer tdee,
    Integer targetKcal,
    Integer proteinG,
    Integer carbsG,
    Integer fatG,
    Integer waterMl,
    List<String> focusMuscles,
    Double waistCm,
    Double hipCm,
    Double chestCm,
    Double armCm
) {}
