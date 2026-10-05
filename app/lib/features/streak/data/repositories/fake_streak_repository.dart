import '../../domain/models/streak_models.dart';
import '../../domain/repositories/streak_repository.dart';

class FakeStreakRepository implements StreakRepository {
  StreakView streakView;
  Map<String, StreakWeekDetail> weekDetails;
  Exception? errorToThrow;

  FakeStreakRepository({
    StreakView? initialStreak,
    Map<String, StreakWeekDetail>? initialWeekDetails,
    this.errorToThrow,
  }) : streakView =
           initialStreak ??
           StreakView(
             currentWeeks: 4,
             bestWeeks: 6,
             freezesAvailable: 1,
             thisWeek: const StreakWeek(
               weekStart: '2026-09-28',
               targetSessions: 3,
               completedSessions: 2,
               status: 'in_progress',
             ),
             weeks: [
               const StreakWeek(
                 weekStart: '2026-08-10',
                 targetSessions: 3,
                 completedSessions: 3,
                 status: 'achieved',
               ),
               const StreakWeek(
                 weekStart: '2026-08-17',
                 targetSessions: 3,
                 completedSessions: 3,
                 status: 'achieved',
               ),
               const StreakWeek(
                 weekStart: '2026-08-24',
                 targetSessions: 3,
                 completedSessions: 0,
                 status: 'frozen',
               ),
               const StreakWeek(
                 weekStart: '2026-08-31',
                 targetSessions: 3,
                 completedSessions: 3,
                 status: 'achieved',
               ),
               const StreakWeek(
                 weekStart: '2026-09-07',
                 targetSessions: 3,
                 completedSessions: 3,
                 status: 'achieved',
               ),
               const StreakWeek(
                 weekStart: '2026-09-14',
                 targetSessions: 3,
                 completedSessions: 3,
                 status: 'achieved',
               ),
               const StreakWeek(
                 weekStart: '2026-09-21',
                 targetSessions: 3,
                 completedSessions: 3,
                 status: 'achieved',
               ),
               const StreakWeek(
                 weekStart: '2026-09-28',
                 targetSessions: 3,
                 completedSessions: 2,
                 status: 'in_progress',
               ),
             ],
           ),
       weekDetails = initialWeekDetails ?? {};

  @override
  Future<StreakView> getStreak() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return streakView;
  }

  @override
  Future<StreakWeekDetail> getWeekDetail(String weekStart) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (weekDetails.containsKey(weekStart)) {
      return weekDetails[weekStart]!;
    }

    // Default mock detail for 7 days
    DateTime start;
    try {
      start = DateTime.parse(weekStart);
    } catch (_) {
      start = DateTime(2026, 10, 5);
    }

    final days = List.generate(7, (i) {
      final curDate = start.add(Duration(days: i));
      final dateStr =
          '${curDate.year}-${curDate.month.toString().padLeft(2, '0')}-${curDate.day.toString().padLeft(2, '0')}';
      final weekday = i + 1;

      List<StreakSessionItem> sessions = [];
      List<StreakWorkoutItem> workouts = [];

      if (weekday == 1) {
        sessions = [
          StreakSessionItem(
            id: 's-1',
            title: 'Toàn thân cơ bản',
            scheduledTime: '18:30',
            durationMin: 15,
            status: 'completed',
          ),
        ];
        workouts = [
          StreakWorkoutItem(
            id: 'w-1',
            startedAt: '${dateStr}T11:20:00Z',
            durationMin: 12,
            countsForStreak: true,
            plannedSessionId: 's-1',
          ),
        ];
      } else if (weekday == 3) {
        sessions = [
          StreakSessionItem(
            id: 's-2',
            title: 'Cardio ngực bụng',
            scheduledTime: '07:00',
            durationMin: 20,
            status: 'planned',
          ),
        ];
      } else if (weekday == 5) {
        sessions = [
          StreakSessionItem(
            id: 's-3',
            title: 'Thân dưới cơ bản',
            scheduledTime: '19:00',
            durationMin: 15,
            status: 'skipped',
          ),
        ];
        workouts = [
          StreakWorkoutItem(
            id: 'w-extra',
            startedAt: '${dateStr}T20:00:00Z',
            durationMin: 4,
            countsForStreak: false,
            plannedSessionId: null,
          ),
        ];
      }

      return StreakDayDetail(
        date: dateStr,
        weekday: weekday,
        sessions: sessions,
        workouts: workouts,
      );
    });

    return StreakWeekDetail(
      weekStart: weekStart,
      status: 'in_progress',
      targetSessions: 2,
      completedSessions: 1,
      days: days,
    );
  }
}
