import 'body_shape.dart';

double? _d(Object? v) => v is num ? v.toDouble() : null;
int? _i(Object? v) => v is num ? v.round() : null;

/// GET /me/body: chỉ số cơ thể. Trường nào cũng có thể null.
class BodyStats {
  const BodyStats({
    this.gender,
    this.age,
    this.heightCm,
    this.weightKg,
    this.bmi,
    this.bmiCategory,
    this.bodyFatPct,
    this.bodyFatEstimated = false,
    this.bmr,
    this.tdee,
    this.targetKcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.waterMl,
    this.focusMuscles = const [],
  });

  final String? gender;
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final double? bmi;

  /// underweight | normal | overweight | obese
  final String? bmiCategory;
  final double? bodyFatPct;
  final bool bodyFatEstimated;
  final int? bmr;
  final int? tdee;
  final int? targetKcal;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;
  final int? waterMl;
  final List<String> focusMuscles;

  bool get female => gender == 'female';

  BodyShape get shape => BodyShape.from(
    bmi: bmi ?? computeBmi(heightCm, weightKg),
    bodyFatPct: bodyFatPct,
    female: female,
  );

  factory BodyStats.fromJson(Map<String, dynamic> json) => BodyStats(
    gender: json['gender'] as String?,
    age: _i(json['age']),
    heightCm: _d(json['heightCm']),
    weightKg: _d(json['weightKg']),
    bmi: _d(json['bmi']),
    bmiCategory: json['bmiCategory'] as String?,
    bodyFatPct: _d(json['bodyFatPct']),
    bodyFatEstimated: json['bodyFatEstimated'] == true,
    bmr: _i(json['bmr']),
    tdee: _i(json['tdee']),
    targetKcal: _i(json['targetKcal']),
    proteinG: _i(json['proteinG']),
    carbsG: _i(json['carbsG']),
    fatG: _i(json['fatG']),
    waterMl: _i(json['waterMl']),
    focusMuscles: (json['focusMuscles'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .where(kMuscleGroups.contains)
        .toList(),
  );
}

/// GET /me/muscles/week: số hiệp đã tập theo nhóm cơ trong tuần.
class MuscleWeek {
  const MuscleWeek({this.weekStart, this.sets = const {}});

  final String? weekStart;
  final Map<String, int> sets;

  int get maxSets => sets.values.fold(0, (a, b) => b > a ? b : a);

  bool get isEmpty => maxSets == 0;

  /// Mức 0..1 theo nhóm cơ (so với nhóm tập nhiều nhất trong tuần).
  Map<String, double> get heat {
    final max = maxSets;
    return {
      for (final m in kMuscleGroups) m: max == 0 ? 0.0 : (sets[m] ?? 0) / max,
    };
  }

  factory MuscleWeek.fromJson(Map<String, dynamic> json) {
    final raw = json['muscles'] as Map<String, dynamic>? ?? const {};
    return MuscleWeek(
      weekStart: json['weekStart'] as String?,
      sets: {
        for (final m in kMuscleGroups)
          m: raw[m] is num ? (raw[m] as num).round().clamp(0, 9999) : 0,
      },
    );
  }
}
