class Measurement {
  const Measurement({
    required this.measuredOn,
    this.weightKg,
    this.waistCm,
    this.hipCm,
    this.chestCm,
    this.armCm,
    this.bodyFatPct,
  });
  final String measuredOn;
  final double? weightKg, waistCm, hipCm, chestCm, armCm, bodyFatPct;
  factory Measurement.fromJson(Map<String, dynamic> j) => Measurement(
    measuredOn: j['measuredOn'] as String,
    weightKg: (j['weightKg'] as num?)?.toDouble(),
    waistCm: (j['waistCm'] as num?)?.toDouble(),
    hipCm: (j['hipCm'] as num?)?.toDouble(),
    chestCm: (j['chestCm'] as num?)?.toDouble(),
    armCm: (j['armCm'] as num?)?.toDouble(),
    bodyFatPct: (j['bodyFatPct'] as num?)?.toDouble(),
  );
}

class MeasurementRequest {
  const MeasurementRequest({
    this.weightKg,
    this.waistCm,
    this.hipCm,
    this.chestCm,
    this.armCm,
  });
  final double? weightKg, waistCm, hipCm, chestCm, armCm;
  bool get hasValue =>
      [weightKg, waistCm, hipCm, chestCm, armCm].any((v) => v != null);
  // Omit measuredOn: backend assigns today's localDate using users.timezone.
  Map<String, dynamic> toJson() => {
    if (weightKg != null) 'weightKg': weightKg,
    if (waistCm != null) 'waistCm': waistCm,
    if (hipCm != null) 'hipCm': hipCm,
    if (chestCm != null) 'chestCm': chestCm,
    if (armCm != null) 'armCm': armCm,
  };
}

class ProgressAchievement {
  const ProgressAchievement({
    required this.code,
    this.nameVi,
    this.descriptionVi,
  });
  final String code;
  final String? nameVi, descriptionVi;
  factory ProgressAchievement.fromJson(Map<String, dynamic> j) =>
      ProgressAchievement(
        code: j['code'] as String,
        nameVi: j['nameVi'] as String?,
        descriptionVi: j['descriptionVi'] as String?,
      );
}

class MeasurementSaveResult {
  const MeasurementSaveResult({
    required this.measurement,
    this.newAchievements = const [],
  });
  final Measurement measurement;
  final List<ProgressAchievement> newAchievements;
  factory MeasurementSaveResult.fromJson(Map<String, dynamic> j) =>
      MeasurementSaveResult(
        measurement: Measurement.fromJson(j['measurement']),
        newAchievements: (j['newAchievements'] as List)
            .map((e) => ProgressAchievement.fromJson(e))
            .toList(),
      );
}

class MeasurementHistory {
  const MeasurementHistory({this.days = 90, this.items = const []});
  final int days;
  final List<Measurement> items;
  factory MeasurementHistory.fromJson(Map<String, dynamic> j) =>
      MeasurementHistory(
        days: (j['days'] as num).toInt(),
        items: (j['items'] as List)
            .map((e) => Measurement.fromJson(e))
            .toList(),
      );
}
