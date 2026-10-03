class NutritionTarget {
  final String? effectiveFrom;
  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int waterMl;
  final String? method;

  const NutritionTarget({
    this.effectiveFrom,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.waterMl,
    this.method,
  });

  factory NutritionTarget.fromJson(Map<String, dynamic> json) {
    return NutritionTarget(
      effectiveFrom: json['effectiveFrom'] as String?,
      kcal: (json['kcal'] as num?)?.toInt() ?? 0,
      proteinG: (json['proteinG'] as num?)?.toInt() ?? 0,
      carbsG: (json['carbsG'] as num?)?.toInt() ?? 0,
      fatG: (json['fatG'] as num?)?.toInt() ?? 0,
      waterMl: (json['waterMl'] as num?)?.toInt() ?? 0,
      method: json['method'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (effectiveFrom != null) 'effectiveFrom': effectiveFrom,
        'kcal': kcal,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'waterMl': waterMl,
        if (method != null) 'method': method,
      };
}

class ItemView {
  final String exerciseId;
  final String? nameVi;
  final int? sets;
  final int? reps;
  final int? durationSec;
  final int? restSec;

  const ItemView({
    required this.exerciseId,
    this.nameVi,
    this.sets,
    this.reps,
    this.durationSec,
    this.restSec,
  });

  factory ItemView.fromJson(Map<String, dynamic> json) {
    return ItemView(
      exerciseId: json['exerciseId']?.toString() ?? '',
      nameVi: json['nameVi'] as String?,
      sets: (json['sets'] as num?)?.toInt(),
      reps: (json['reps'] as num?)?.toInt(),
      durationSec: (json['durationSec'] as num?)?.toInt(),
      restSec: (json['restSec'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        if (nameVi != null) 'nameVi': nameVi,
        if (sets != null) 'sets': sets,
        if (reps != null) 'reps': reps,
        if (durationSec != null) 'durationSec': durationSec,
        if (restSec != null) 'restSec': restSec,
      };
}

class SessionView {
  final String id;
  final String scheduledDate;
  final String scheduledTime;
  final String title;
  final int durationMin;
  final String? variant;
  final String? status;
  final List<ItemView> items;

  const SessionView({
    required this.id,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.title,
    required this.durationMin,
    this.variant,
    this.status,
    this.items = const [],
  });

  String get dayLabel {
    final dt = DateTime.tryParse(scheduledDate);
    if (dt == null) return '';
    switch (dt.weekday) {
      case DateTime.monday:
        return 'T2';
      case DateTime.tuesday:
        return 'T3';
      case DateTime.wednesday:
        return 'T4';
      case DateTime.thursday:
        return 'T5';
      case DateTime.friday:
        return 'T6';
      case DateTime.saturday:
        return 'T7';
      case DateTime.sunday:
        return 'CN';
      default:
        return '';
    }
  }

  int get exerciseCount => items.length;
  int get durationMinutes => durationMin;

  factory SessionView.fromJson(Map<String, dynamic> json) {
    return SessionView(
      id: json['id']?.toString() ?? '',
      scheduledDate: json['scheduledDate']?.toString() ?? '',
      scheduledTime: json['scheduledTime']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      durationMin: (json['durationMin'] as num?)?.toInt() ?? 0,
      variant: json['variant'] as String?,
      status: json['status'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ItemView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'scheduledDate': scheduledDate,
        'scheduledTime': scheduledTime,
        'title': title,
        'durationMin': durationMin,
        if (variant != null) 'variant': variant,
        if (status != null) 'status': status,
        'items': items.map((i) => i.toJson()).toList(),
      };
}

class PlanView {
  final String id;
  final String weekStart;
  final String status;
  final int targetSessions;
  final List<SessionView> sessions;
  final String? injuryNote;

  const PlanView({
    required this.id,
    required this.weekStart,
    required this.status,
    required this.targetSessions,
    required this.sessions,
    this.injuryNote,
  });

  factory PlanView.fromJson(Map<String, dynamic> json) {
    return PlanView(
      id: json['id']?.toString() ?? '',
      weekStart: json['weekStart']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      targetSessions: (json['targetSessions'] as num?)?.toInt() ?? 0,
      sessions: (json['sessions'] as List<dynamic>?)
              ?.map((e) => SessionView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      injuryNote: json['injuryNote'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'weekStart': weekStart,
        'status': status,
        'targetSessions': targetSessions,
        'sessions': sessions.map((s) => s.toJson()).toList(),
        if (injuryNote != null) 'injuryNote': injuryNote,
      };
}

// Giữ lại lớp cũ để tương thích ngược nếu cần
typedef WorkoutSessionItem = SessionView;
typedef WeeklyPlan = PlanView;
