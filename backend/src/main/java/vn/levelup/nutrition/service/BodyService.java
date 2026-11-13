package vn.levelup.nutrition.service;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

import org.springframework.stereotype.Service;
import vn.levelup.identity.model.User;
import vn.levelup.nutrition.dto.BodyView;
import vn.levelup.nutrition.rules.BodyRules;
import vn.levelup.nutrition.rules.NutritionCalculator;
import vn.levelup.nutrition.rules.NutritionRules;
import vn.levelup.shared.util.LocalDates;
import vn.levelup.training.service.MeasurementService;

/** GET /me/body: gom hồ sơ, số đo mới nhất và mục tiêu dinh dưỡng đang áp dụng. */
@Service
public class BodyService {

    private final MeasurementService measurements;
    private final Clock clock;

    public BodyService(MeasurementService measurements, Clock clock) {
        this.measurements = measurements;
        this.clock = clock;
    }

    public BodyView body(User user) {
        User.Profile p = user.profile();
        LocalDate today = LocalDates.today(user.timezone(), clock);
        String gender = p == null ? null : p.gender();
        Integer birthYear = p == null ? null : p.birthYear();
        Double height = p == null ? null : p.heightCm();
        Double weight = measurements.latestWeightKg(user.id()).orElse(p == null ? null : p.startWeightKg());

        // Tuổi hiển thị: chỉ khi biết năm sinh. Công thức thì dùng tuổi mặc định như lúc tính mục tiêu calo.
        Integer age = birthYear == null ? null : Math.max(0, today.getYear() - birthYear);
        int formulaAge = NutritionCalculator.age(birthYear, today);

        Double bmi = BodyRules.bmi(height, weight);
        BodyRules.BodyFat fat = BodyRules.bodyFat(measurements.latestBodyFatPct(user.id()).orElse(null),
            p == null ? null : p.bodyFatPct(), bmi, formulaAge, gender);

        Integer bmr = null;
        Integer tdee = null;
        if (height != null && weight != null) {
            double b = NutritionCalculator.bmr(gender, formulaAge, height, weight);
            bmr = (int) Math.round(b);
            tdee = (int) Math.round(NutritionCalculator.tdee(b));
        }
        NutritionRules.Target t = NutritionRules.effectiveTarget(user.nutritionTargets(), today, gender);
        List<String> focus = p == null || p.focusMuscles() == null ? List.of() : p.focusMuscles();
        return new BodyView(gender, age, height, weight, bmi, BodyRules.bmiCategory(bmi), fat.pct(),
            fat.estimated(), bmr, tdee, t == null ? null : t.kcal(), t == null ? null : t.proteinG(),
            t == null ? null : t.carbsG(), t == null ? null : t.fatG(), t == null ? null : t.waterMl(), focus);
    }
}
