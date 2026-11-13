import '../../domain/models/body_models.dart';
import '../../domain/repositories/body_repository.dart';

class FakeBodyRepository implements BodyRepository {
  FakeBodyRepository({BodyStats? stats, MuscleWeek? week})
    : stats =
          stats ??
          const BodyStats(
            gender: 'male',
            age: 28,
            heightCm: 170,
            weightKg: 68,
            bmi: 23.5,
            bmiCategory: 'normal',
            bodyFatPct: 19,
            bodyFatEstimated: true,
            bmr: 1620,
            tdee: 2230,
            targetKcal: 1900,
            proteinG: 120,
            carbsG: 210,
            fatG: 60,
            waterMl: 2400,
            focusMuscles: ['abs', 'chest'],
          ),
      week =
          week ??
          const MuscleWeek(
            weekStart: '2026-11-09',
            sets: {
              'chest': 6,
              'back': 0,
              'shoulders': 3,
              'arms': 4,
              'abs': 9,
              'glutes': 0,
              'legs': 12,
            },
          );

  BodyStats stats;
  MuscleWeek week;
  Object? bodyError, weekError;
  int bodyCalls = 0, weekCalls = 0;
  String? lastWeekStart;

  @override
  Future<BodyStats> getBody() async {
    bodyCalls++;
    if (bodyError != null) throw bodyError!;
    return stats;
  }

  @override
  Future<MuscleWeek> getMusclesWeek({String? weekStart}) async {
    weekCalls++;
    lastWeekStart = weekStart;
    if (weekError != null) throw weekError!;
    return week;
  }
}
