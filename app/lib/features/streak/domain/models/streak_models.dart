import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class StreakWeek {
  final String weekStart;
  final int targetSessions;
  final int completedSessions;
  final String status; // achieved | missed | frozen | in_progress | none (or legacy: completed | broken)

  const StreakWeek({
    required this.weekStart,
    required this.targetSessions,
    required this.completedSessions,
    required this.status,
  });

  bool get isAchieved => status == 'achieved' || status == 'completed';
  bool get isMissed => status == 'missed' || status == 'broken';
  bool get isFrozen => status == 'frozen';
  bool get isInProgress => status == 'in_progress';
  bool get isNone => status == 'none';
  bool get isCompleted => isAchieved;
  bool get isBroken => isMissed;

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
      weeks:
          (json['weeks'] as List<dynamic>?)
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

class StreakWeekDetail {
  final String weekStart;
  final String status;
  final int targetSessions;
  final int completedSessions;
  final List<StreakDayDetail> days;

  const StreakWeekDetail({
    required this.weekStart,
    required this.status,
    required this.targetSessions,
    required this.completedSessions,
    this.days = const [],
  });

  factory StreakWeekDetail.fromJson(Map<String, dynamic> json) {
    return StreakWeekDetail(
      weekStart: json['weekStart']?.toString() ?? '',
      status: json['status']?.toString() ?? 'in_progress',
      targetSessions: (json['targetSessions'] as num?)?.toInt() ?? 0,
      completedSessions: (json['completedSessions'] as num?)?.toInt() ?? 0,
      days:
          (json['days'] as List<dynamic>?)
              ?.map((e) => StreakDayDetail.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'weekStart': weekStart,
    'status': status,
    'targetSessions': targetSessions,
    'completedSessions': completedSessions,
    'days': days.map((d) => d.toJson()).toList(),
  };
}

class StreakDayDetail {
  final String date;
  final int weekday;
  final List<StreakSessionItem> sessions;
  final List<StreakWorkoutItem> workouts;

  const StreakDayDetail({
    required this.date,
    required this.weekday,
    this.sessions = const [],
    this.workouts = const [],
  });

  factory StreakDayDetail.fromJson(Map<String, dynamic> json) {
    return StreakDayDetail(
      date: json['date']?.toString() ?? '',
      weekday: (json['weekday'] as num?)?.toInt() ?? 1,
      sessions:
          (json['sessions'] as List<dynamic>?)
              ?.map(
                (e) => StreakSessionItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      workouts:
          (json['workouts'] as List<dynamic>?)
              ?.map(
                (e) => StreakWorkoutItem.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'weekday': weekday,
    'sessions': sessions.map((s) => s.toJson()).toList(),
    'workouts': workouts.map((w) => w.toJson()).toList(),
  };
}

class StreakSessionItem {
  final String id;
  final String title;
  final String? scheduledTime;
  final int durationMin;
  final String status; // planned | completed | skipped | rescheduled | rest

  const StreakSessionItem({
    required this.id,
    required this.title,
    this.scheduledTime,
    required this.durationMin,
    required this.status,
  });

  factory StreakSessionItem.fromJson(Map<String, dynamic> json) {
    return StreakSessionItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      scheduledTime: json['scheduledTime']?.toString(),
      durationMin: (json['durationMin'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'planned',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (scheduledTime != null) 'scheduledTime': scheduledTime,
    'durationMin': durationMin,
    'status': status,
  };
}

class StreakWorkoutItem {
  final String id;
  final String startedAt;
  final int durationMin;
  final bool countsForStreak;
  final String? plannedSessionId;

  const StreakWorkoutItem({
    required this.id,
    required this.startedAt,
    required this.durationMin,
    required this.countsForStreak,
    this.plannedSessionId,
  });

  factory StreakWorkoutItem.fromJson(Map<String, dynamic> json) {
    return StreakWorkoutItem(
      id: json['id']?.toString() ?? '',
      startedAt: json['startedAt']?.toString() ?? '',
      durationMin: (json['durationMin'] as num?)?.toInt() ?? 0,
      countsForStreak: json['countsForStreak'] as bool? ?? false,
      plannedSessionId: json['plannedSessionId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt,
    'durationMin': durationMin,
    'countsForStreak': countsForStreak,
    if (plannedSessionId != null) 'plannedSessionId': plannedSessionId,
  };
}

String formatWeekRange(String weekStart) {
  try {
    final start = DateTime.parse(weekStart);
    final end = start.add(const Duration(days: 6));
    final startStr =
        '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')}';
    final endStr =
        '${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}';
    return 'Tuần $startStr – $endStr';
  } catch (_) {
    return 'Tuần $weekStart';
  }
}

class WeekStatusInfo {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const WeekStatusInfo({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
  });
}

WeekStatusInfo mapWeekStatus(String status) {
  switch (status) {
    case 'achieved':
    case 'completed':
      return const WeekStatusInfo(
        label: 'Đạt',
        icon: Icons.check_circle_rounded,
        color: AppColors.primary,
        bgColor: AppColors.primaryLight,
      );
    case 'missed':
    case 'broken':
      return const WeekStatusInfo(
        label: 'Chưa đạt',
        icon: Icons.cancel_outlined,
        color: Colors.redAccent,
        bgColor: Color(0xFFFEE2E2),
      );
    case 'frozen':
      return const WeekStatusInfo(
        label: 'Dùng thẻ đóng băng',
        icon: Icons.ac_unit_rounded,
        color: Color(0xFF0284C7),
        bgColor: Color(0xFFE0F2FE),
      );
    case 'in_progress':
      return const WeekStatusInfo(
        label: 'Đang diễn ra',
        icon: Icons.timelapse_rounded,
        color: AppColors.accentLink,
        bgColor: AppColors.primaryLight,
      );
    case 'none':
    default:
      return const WeekStatusInfo(
        label: 'Không có dữ liệu',
        icon: Icons.radio_button_unchecked_rounded,
        color: AppColors.textSecondary,
        bgColor: Color(0xFFF3F4F6),
      );
  }
}
