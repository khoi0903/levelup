class StreakWeek {
  final String weekStart;
  final int targetSessions;
  final int completedSessions;
  final String status; // completed | frozen | broken | in_progress

  const StreakWeek({
    required this.weekStart,
    required this.targetSessions,
    required this.completedSessions,
    required this.status,
  });

  bool get isCompleted => status == 'completed';
  bool get isFrozen => status == 'frozen';
  bool get isBroken => status == 'broken';
  bool get isInProgress => status == 'in_progress';

  factory StreakWeek.fromJson(Map<String, dynamic> json) {
    return StreakWeek(
      weekStart: json['weekStart']?.toString() ?? '',
      targetSessions: (json['targetSessions'] as num?)?.toInt() ?? 0,
      completedSessions: (json['completedSessions'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'in_progress',
    );
  }

  Map<String, dynamic> toJson() => {
        'weekStart': weekStart,
        'targetSessions': targetSessions,
        'completedSessions': completedSessions,
        'status': status,
      };
}

class StreakView {
  final int currentWeeks;
  final int bestWeeks;
  final int freezesAvailable;
  final StreakWeek? thisWeek;
  final List<StreakWeek> weeks;

  const StreakView({
    required this.currentWeeks,
    required this.bestWeeks,
    required this.freezesAvailable,
    this.thisWeek,
    this.weeks = const [],
  });

  factory StreakView.fromJson(Map<String, dynamic> json) {
    return StreakView(
      currentWeeks: (json['currentWeeks'] as num?)?.toInt() ?? 0,
      bestWeeks: (json['bestWeeks'] as num?)?.toInt() ?? 0,
      freezesAvailable: (json['freezesAvailable'] as num?)?.toInt() ?? 0,
      thisWeek: json['thisWeek'] != null
          ? StreakWeek.fromJson(json['thisWeek'] as Map<String, dynamic>)
          : null,
      weeks: (json['weeks'] as List<dynamic>?)
              ?.map((e) => StreakWeek.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'currentWeeks': currentWeeks,
        'bestWeeks': bestWeeks,
        'freezesAvailable': freezesAvailable,
        if (thisWeek != null) 'thisWeek': thisWeek!.toJson(),
        'weeks': weeks.map((w) => w.toJson()).toList(),
      };
}
