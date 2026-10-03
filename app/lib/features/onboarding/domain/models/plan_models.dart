class WorkoutSessionItem {
  final String dayLabel; // "T2", "T4", "T6"
  final String title; // "Toàn thân cơ bản"
  final int durationMinutes; // 12
  final int exerciseCount; // 6

  const WorkoutSessionItem({
    required this.dayLabel,
    required this.title,
    required this.durationMinutes,
    required this.exerciseCount,
  });
}

class WeeklyPlan {
  final String title;
  final String subtitle;
  final List<WorkoutSessionItem> sessions;
  final String? injuryNote;

  const WeeklyPlan({
    required this.title,
    required this.subtitle,
    required this.sessions,
    this.injuryNote,
  });
}
