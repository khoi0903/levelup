class ActivitySyncRequest {
  final String localDate;
  final int steps;
  final int activeKcal;

  /// Calo vận động Health Connect ghi trong giờ các buổi tập trong app (để server cộng không trùng).
  final int? activeKcalInWorkouts;

  const ActivitySyncRequest({
    required this.localDate,
    required this.steps,
    required this.activeKcal,
    this.activeKcalInWorkouts,
  });

  Map<String, dynamic> toJson() => {
    'localDate': localDate,
    'steps': steps,
    'activeKcal': activeKcal,
    if (activeKcalInWorkouts != null)
      'activeKcalInWorkouts': activeKcalInWorkouts,
  };
}

class ActivitySyncResponse {
  final String localDate;
  final int steps;
  final int activeKcal;
  final bool stored;

  const ActivitySyncResponse({
    required this.localDate,
    required this.steps,
    required this.activeKcal,
    required this.stored,
  });

  factory ActivitySyncResponse.fromJson(Map<String, dynamic> json) =>
      ActivitySyncResponse(
        localDate: json['localDate'] as String? ?? '',
        steps: (json['steps'] as num?)?.toInt() ?? 0,
        activeKcal: (json['activeKcal'] as num?)?.toInt() ?? 0,
        stored: json['stored'] as bool? ?? false,
      );
}

/// Một buổi tập trong app hôm nay (giờ máy chủ đã lưu).
class WorkoutWindow {
  final DateTime startedAt;
  final DateTime endedAt;

  const WorkoutWindow({required this.startedAt, required this.endedAt});

  factory WorkoutWindow.fromJson(Map<String, dynamic> json) => WorkoutWindow(
    startedAt: DateTime.parse(json['startedAt'] as String),
    endedAt: DateTime.parse(json['endedAt'] as String),
  );
}

/// GET /activity/today: số trên máy chủ (lớn nhất giữa các điện thoại) và giờ các buổi tập hôm nay.
class ActivityToday {
  final String localDate;
  final int steps;
  final int activeKcal;
  final List<WorkoutWindow> workoutWindows;

  const ActivityToday({
    required this.localDate,
    this.steps = 0,
    this.activeKcal = 0,
    this.workoutWindows = const [],
  });

  factory ActivityToday.fromJson(Map<String, dynamic> json) => ActivityToday(
    localDate: json['localDate'] as String? ?? '',
    steps: (json['steps'] as num?)?.toInt() ?? 0,
    activeKcal: (json['activeKcal'] as num?)?.toInt() ?? 0,
    workoutWindows: ((json['workoutWindows'] as List?) ?? const [])
        .map((e) => WorkoutWindow.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// Một ngày trong GET /activity/history.
class ActivityDay {
  final String localDate;
  final int steps;
  final int activeKcal;
  final int workoutKcal;
  final int totalBurnedKcal;

  const ActivityDay({
    required this.localDate,
    this.steps = 0,
    this.activeKcal = 0,
    this.workoutKcal = 0,
    this.totalBurnedKcal = 0,
  });

  /// Calo đi lại, vận động ngoài các buổi tập trong app.
  int get otherKcal =>
      totalBurnedKcal > workoutKcal ? totalBurnedKcal - workoutKcal : 0;

  factory ActivityDay.fromJson(Map<String, dynamic> json) => ActivityDay(
    localDate: json['localDate'] as String? ?? '',
    steps: (json['steps'] as num?)?.toInt() ?? 0,
    activeKcal: (json['activeKcal'] as num?)?.toInt() ?? 0,
    workoutKcal: (json['workoutKcal'] as num?)?.toInt() ?? 0,
    totalBurnedKcal: (json['totalBurnedKcal'] as num?)?.toInt() ?? 0,
  );
}
