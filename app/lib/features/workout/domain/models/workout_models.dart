/// Mô hình cho POST /workouts. Tên trường khớp đúng
/// backend/src/main/java/vn/levelup/workouts/WorkoutRequest.java và WorkoutResponse.java.
library;

/// Nguồn của số lần trong một hiệp, khớp regex `manual|camera|camera_corrected`.
enum RepSource {
  manual('manual'),
  camera('camera'),
  cameraCorrected('camera_corrected');

  const RepSource(this.json);
  final String json;
}

/// Vùng đau người dùng báo sau buổi, khớp `lower_back|knee|...|other`.
enum PainArea {
  lowerBack('lower_back', 'Lưng dưới'),
  knee('knee', 'Gối'),
  shoulder('shoulder', 'Vai'),
  neck('neck', 'Cổ'),
  wrist('wrist', 'Cổ tay'),
  ankle('ankle', 'Cổ chân'),
  hip('hip', 'Hông'),
  other('other', 'Khác');

  const PainArea(this.json, this.labelVi);
  final String json;
  final String labelVi;
}

class FormIssueLog {
  final int repIndex;
  final String code;
  final int severity;

  const FormIssueLog({
    required this.repIndex,
    required this.code,
    required this.severity,
  });

  Map<String, dynamic> toJson() => {
    'repIndex': repIndex,
    'code': code,
    'severity': severity,
  };

  factory FormIssueLog.fromJson(Map<String, dynamic> json) => FormIssueLog(
    repIndex: (json['repIndex'] as num).toInt(),
    code: json['code'] as String,
    severity: (json['severity'] as num).toInt(),
  );
}

/// Một hiệp đã tập, ứng với `WorkoutRequest.SetLog`.
class SetLog {
  final String exerciseId;
  final int setIndex;
  final int? reps;
  final double? weightKg;
  final int? durationSec;
  final RepSource repSource;
  final int? repsDetected;
  final int? cvVersion;
  final double? avgConfidence;
  final int? formScore;
  final List<FormIssueLog> formIssues;

  const SetLog({
    required this.exerciseId,
    required this.setIndex,
    this.reps,
    this.weightKg,
    this.durationSec,
    this.repSource = RepSource.manual,
    this.repsDetected,
    this.cvVersion,
    this.avgConfidence,
    this.formScore,
    this.formIssues = const [],
  });

  SetLog withSetIndex(int index) => SetLog(
    exerciseId: exerciseId,
    setIndex: index,
    reps: reps,
    weightKg: weightKg,
    durationSec: durationSec,
    repSource: repSource,
    repsDetected: repsDetected,
    cvVersion: cvVersion,
    avgConfidence: avgConfidence,
    formScore: formScore,
    formIssues: formIssues,
  );

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'setIndex': setIndex,
    if (reps != null) 'reps': reps,
    if (weightKg != null) 'weightKg': weightKg,
    if (durationSec != null) 'durationSec': durationSec,
    'repSource': repSource.json,
    if (repsDetected != null) 'repsDetected': repsDetected,
    if (cvVersion != null) 'cvVersion': cvVersion,
    if (avgConfidence != null) 'avgConfidence': avgConfidence,
    if (formScore != null) 'formScore': formScore,
    if (formIssues.isNotEmpty)
      'formIssues': formIssues.map((i) => i.toJson()).toList(),
  };

  factory SetLog.fromJson(Map<String, dynamic> json) => SetLog(
    exerciseId: json['exerciseId'] as String,
    setIndex: (json['setIndex'] as num).toInt(),
    reps: (json['reps'] as num?)?.toInt(),
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    durationSec: (json['durationSec'] as num?)?.toInt(),
    repSource: RepSource.values.firstWhere(
      (s) => s.json == json['repSource'],
      orElse: () => RepSource.manual,
    ),
    repsDetected: (json['repsDetected'] as num?)?.toInt(),
    cvVersion: (json['cvVersion'] as num?)?.toInt(),
    avgConfidence: (json['avgConfidence'] as num?)?.toDouble(),
    formScore: (json['formScore'] as num?)?.toInt(),
    formIssues: (json['formIssues'] as List<dynamic>?)
            ?.map((i) => FormIssueLog.fromJson(i as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

class WorkoutRequest {
  final String clientId;
  final String? plannedSessionId;
  final DateTime startedAt;
  final DateTime endedAt;
  final String variant;
  final int? rpe;
  final List<PainArea> painAreas;
  final String? painType;
  final String? note;
  final List<SetLog> sets;

  const WorkoutRequest({
    required this.clientId,
    this.plannedSessionId,
    required this.startedAt,
    required this.endedAt,
    required this.variant,
    this.rpe,
    this.painAreas = const [],
    this.painType,
    this.note,
    required this.sets,
  });

  Map<String, dynamic> toJson() => {
    'clientId': clientId,
    if (plannedSessionId != null) 'plannedSessionId': plannedSessionId,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
    'variant': variant,
    if (rpe != null) 'rpe': rpe,
    if (painAreas.isNotEmpty)
      'painAreas': painAreas.map((p) => p.json).toList(),
    if (painAreas.isNotEmpty && painType != null) 'painType': painType,
    if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
    'sets': sets.map((s) => s.toJson()).toList(),
  };
}

class WeekProgress {
  final String weekStart;
  final int targetSessions;
  final int completedSessions;
  final String status;

  const WeekProgress({
    required this.weekStart,
    required this.targetSessions,
    required this.completedSessions,
    required this.status,
  });

  bool get achieved => status == 'achieved';

  factory WeekProgress.fromJson(Map<String, dynamic> json) => WeekProgress(
    weekStart: json['weekStart']?.toString() ?? '',
    targetSessions: (json['targetSessions'] as num?)?.toInt() ?? 0,
    completedSessions: (json['completedSessions'] as num?)?.toInt() ?? 0,
    status: json['status']?.toString() ?? 'in_progress',
  );
}

class PersonalRecord {
  final String exerciseId;
  final String? nameVi;
  final String metric; // max_reps | max_weight | max_duration
  final double value;
  final double? previous;

  const PersonalRecord({
    required this.exerciseId,
    this.nameVi,
    required this.metric,
    required this.value,
    this.previous,
  });

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
    exerciseId: json['exerciseId']?.toString() ?? '',
    nameVi: json['nameVi'] as String?,
    metric: json['metric']?.toString() ?? '',
    value: (json['value'] as num?)?.toDouble() ?? 0,
    previous: (json['previous'] as num?)?.toDouble(),
  );

  /// "12 lần", "8 kg", "45 giây".
  static String formatValue(String metric, double value) {
    final text = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return switch (metric) {
      'max_weight' => '$text kg',
      'max_duration' => '$text giây',
      _ => '$text lần',
    };
  }

  String get metricLabelVi => switch (metric) {
    'max_weight' => 'Tạ nặng nhất',
    'max_duration' => 'Giữ lâu nhất',
    _ => 'Nhiều lần nhất',
  };
}

class Achievement {
  final String code;
  final String nameVi;
  final String? descriptionVi;
  final String? category;
  final String? earnedAt;

  const Achievement({
    required this.code,
    required this.nameVi,
    this.descriptionVi,
    this.category,
    this.earnedAt,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    code: json['code']?.toString() ?? '',
    nameVi: json['nameVi']?.toString() ?? json['code']?.toString() ?? '',
    descriptionVi: json['descriptionVi'] as String?,
    category: json['category'] as String?,
    earnedAt: json['earnedAt'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'nameVi': nameVi,
    if (descriptionVi != null) 'descriptionVi': descriptionVi,
    if (category != null) 'category': category,
    if (earnedAt != null) 'earnedAt': earnedAt,
  };
}

/// Ứng với `WorkoutResponse`.
class WorkoutResult {
  final String workoutId;
  final String localDate;
  final int durationSec;
  final bool countsForStreak;
  final bool duplicate;
  final WeekProgress? week;
  final List<PersonalRecord> personalRecords;
  final List<Achievement> newAchievements;
  final int kcalBurned;

  const WorkoutResult({
    required this.workoutId,
    required this.localDate,
    required this.durationSec,
    required this.countsForStreak,
    this.duplicate = false,
    this.week,
    this.personalRecords = const [],
    this.newAchievements = const [],
    this.kcalBurned = 0,
  });

  factory WorkoutResult.fromJson(Map<String, dynamic> json) => WorkoutResult(
    workoutId: json['workoutId']?.toString() ?? '',
    localDate: json['localDate']?.toString() ?? '',
    durationSec: (json['durationSec'] as num?)?.toInt() ?? 0,
    countsForStreak: json['countsForStreak'] == true,
    duplicate: json['duplicate'] == true,
    week: json['week'] is Map<String, dynamic>
        ? WeekProgress.fromJson(json['week'] as Map<String, dynamic>)
        : null,
    personalRecords:
        (json['personalRecords'] as List<dynamic>?)
            ?.map((e) => PersonalRecord.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    newAchievements:
        (json['newAchievements'] as List<dynamic>?)
            ?.map((e) => Achievement.fromJson(e as Map<String, dynamic>))
            .toList() ??
        const [],
    kcalBurned: (json['kcalBurned'] as num?)?.toInt() ?? 0,
  );
}
