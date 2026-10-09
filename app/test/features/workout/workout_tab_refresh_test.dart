import 'package:fitness_app/features/home/presentation/controllers/home_controller.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_plan_repository.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:fitness_app/features/workout/data/repositories/fake_workout_repository.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test_helpers.dart';

PlanView _plan(String exerciseId, String name) => PlanView(
  id: 'plan',
  weekStart: '2026-10-05',
  status: 'active',
  targetSessions: 1,
  sessions: [
    SessionView(
      id: sessionId,
      scheduledDate: '2026-10-05',
      scheduledTime: '18:00',
      title: 'Toàn thân',
      durationMin: 15,
      status: 'planned',
      items: [
        ItemView(exerciseId: exerciseId, nameVi: name, sets: 2, reps: 10),
      ],
    ),
  ],
);

void main() {
  test('Tab Tập (không sessionId) dựng lại buổi khi kế hoạch được làm mới (coach đổi bài)', () async {
    final planRepo = FakePlanRepository(planView: _plan(squatId, 'Squat'));
    final container = ProviderContainer(
      overrides: [
        planRepositoryProvider.overrideWithValue(planRepo),
        workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        userRepositoryProvider.overrideWithValue(
          FakeUserRepository(
            meResponse: const MeResponse(
              id: 'u',
              displayName: 'Khoi',
              localDate: '2026-10-05',
            ),
          ),
        ),
        workoutClockProvider.overrideWithValue(FakeClock().call),
      ],
    );
    addTearDown(container.dispose);
    const args = (sessionId: null, quick5: false);
    // Tab Tập đang mở: provider được giữ (listen)
    final sub = container.listen(workoutSetupProvider(args), (_, _) {});
    addTearDown(sub.close);
    await container.read(userStatusFutureProvider.future);

    final before = await container.read(workoutSetupProvider(args).future);
    expect(before.items.single.exerciseId, squatId);

    // Coach áp dụng đổi bài: máy chủ đổi kế hoạch, app làm mới homePlanProvider
    planRepo.planView = _plan(plankId, 'Plank');
    container.invalidate(homePlanProvider);

    final after = await container.read(workoutSetupProvider(args).future);
    expect(after.items.single.exerciseId, plankId);
  });
}
