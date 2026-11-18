/// Nhóm cơ dùng chung với backend (`focusMuscles`, `/me/muscles/week`).
const List<String> kMuscleGroups = [
  'chest',
  'back',
  'shoulders',
  'arms',
  'abs',
  'glutes',
  'legs',
];

/// Vùng đau hiển thị trên hình người (trùng tên `BodyArea`, trừ `other`).
const List<String> kPainAreas = [
  'neck',
  'shoulder',
  'lower_back',
  'wrist',
  'hip',
  'knee',
  'ankle',
];

const Map<String, String> kMuscleLabels = {
  'chest': 'Ngực',
  'back': 'Lưng',
  'shoulders': 'Vai',
  'arms': 'Tay',
  'abs': 'Bụng',
  'glutes': 'Mông',
  'legs': 'Chân',
};

const Map<String, String> kPainLabels = {
  'neck': 'Cổ',
  'shoulder': 'Vai',
  'lower_back': 'Lưng dưới',
  'wrist': 'Cổ tay',
  'hip': 'Hông',
  'knee': 'Gối',
  'ankle': 'Cổ chân',
  'other': 'Khác',
};

/// 5 mức vóc dáng gợi ý (tỉ lệ mỡ cơ thể, %).
const List<int> kBodyFatPresetsMale = [12, 18, 24, 30, 36];
const List<int> kBodyFatPresetsFemale = [20, 26, 32, 38, 44];

List<int> bodyFatPresets({required bool female}) =>
    female ? kBodyFatPresetsFemale : kBodyFatPresetsMale;

/// Mức gợi ý gần nhất với [bodyFatPct] (null nếu chưa có).
int? nearestBodyFatPreset(int? bodyFatPct, {required bool female}) {
  if (bodyFatPct == null) return null;
  final presets = bodyFatPresets(female: female);
  var best = presets.first;
  for (final p in presets) {
    if ((p - bodyFatPct).abs() < (best - bodyFatPct).abs()) best = p;
  }
  return best;
}

double? computeBmi(num? heightCm, num? weightKg) {
  if (heightCm == null || weightKg == null || heightCm <= 0 || weightKg <= 0) {
    return null;
  }
  final m = heightCm / 100.0;
  return weightKg / (m * m);
}

/// Kích thước hình người, tính theo tỉ lệ chiều cao hình (nửa bề rộng).
/// Mọi số đo tăng đều theo BMI và tỉ lệ mỡ, đã chặn trong khoảng an toàn.
class BodyShape {
  const BodyShape({
    required this.female,
    required this.shoulder,
    required this.chest,
    required this.waist,
    required this.hip,
    required this.thigh,
    required this.arm,
    this.softness = 0,
    this.belly = 0,
  });

  static const double minBmi = 16, maxBmi = 38;
  static const double minFat = 5, maxFat = 50;

  final bool female;
  final double shoulder;
  final double chest;
  final double waist;
  final double hip;
  final double thigh;
  final double arm;

  /// Độ mềm của nét cơ theo tỉ lệ mỡ: 0 = múi cơ rõ, 1 = không còn thấy múi.
  final double softness;

  /// Mức mỡ thừa dồn về bụng, hông, mặt: 0 = không có, 1 = nhiều nhất.
  /// Tăng đều theo cả BMI và tỉ lệ mỡ.
  final double belly;

  factory BodyShape.from({double? bmi, num? bodyFatPct, bool female = false}) {
    final b = (bmi == null || bmi.isNaN ? 22.0 : bmi).clamp(minBmi, maxBmi);
    final estimatedFat = 1.2 * b + 0.23 * 30 - (female ? 0 : 10.8) - 5.4;
    final f = (bodyFatPct?.toDouble() ?? estimatedFat).clamp(minFat, maxFat);
    final tb = (b - minBmi) / (maxBmi - minBmi);
    final tf = (f - minFat) / (maxFat - minFat);
    // Mỡ thừa: chỉ xuất hiện khi BMI trên 23 hoặc tỉ lệ mỡ trên mức thường,
    // nên vóc dáng gầy / bình thường giữ nguyên.
    final gb = ((b - 23) / 15).clamp(0.0, 1.0);
    final gf = ((f - (female ? 28 : 20)) / 20).clamp(0.0, 1.0);
    final g = (gb * (0.3 + 0.7 * gf) + 0.3 * gf) / 1.3;
    final soft = ((f - (female ? 26 : 16)) / (female ? 12 : 14)).clamp(
      0.0,
      1.0,
    );
    return BodyShape(
      female: female,
      shoulder: (female ? 0.100 : 0.114) + 0.030 * tb + 0.012 * tf + 0.004 * g,
      chest: (female ? 0.078 : 0.086) + 0.034 * tb + 0.020 * tf + 0.008 * g,
      waist: (female ? 0.054 : 0.062) + 0.040 * tb + 0.045 * tf + 0.022 * g,
      hip: (female ? 0.088 : 0.080) + 0.034 * tb + 0.030 * tf + 0.008 * g,
      thigh: (female ? 0.044 : 0.042) + 0.017 * tb + 0.012 * tf + 0.007 * g,
      arm: (female ? 0.020 : 0.023) + 0.009 * tb + 0.008 * tf + 0.004 * g,
      softness: soft,
      belly: g,
    );
  }
}
