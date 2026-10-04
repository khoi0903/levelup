import '../../domain/models/streak_models.dart';
import '../../domain/repositories/streak_repository.dart';

class FakeStreakRepository implements StreakRepository {
  StreakView streakView;
  Exception? errorToThrow;

  FakeStreakRepository({
    StreakView? initialStreak,
    this.errorToThrow,
  }) : streakView = initialStreak ??
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
                  status: 'completed',
                ),
                const StreakWeek(
                  weekStart: '2026-08-17',
                  targetSessions: 3,
                  completedSessions: 3,
                  status: 'completed',
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
                  status: 'completed',
                ),
                const StreakWeek(
                  weekStart: '2026-09-07',
                  targetSessions: 3,
                  completedSessions: 3,
                  status: 'completed',
                ),
                const StreakWeek(
                  weekStart: '2026-09-14',
                  targetSessions: 3,
                  completedSessions: 3,
                  status: 'completed',
                ),
                const StreakWeek(
                  weekStart: '2026-09-21',
                  targetSessions: 3,
                  completedSessions: 3,
                  status: 'completed',
                ),
                const StreakWeek(
                  weekStart: '2026-09-28',
                  targetSessions: 3,
                  completedSessions: 2,
                  status: 'in_progress',
                ),
              ],
            );

  @override
  Future<StreakView> getStreak() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return streakView;
  }
}
