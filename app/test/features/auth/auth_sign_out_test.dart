import 'package:fitness_app/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:fitness_app/features/auth/domain/models/auth_user.dart';
import 'package:fitness_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitness_app/features/onboarding/domain/models/onboarding_models.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:fitness_app/features/workout/data/repositories/memory_workout_draft_repository.dart';
import 'package:fitness_app/features/workout/domain/models/workout_draft.dart';
import 'package:fitness_app/features/workout/domain/models/workout_session_state.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../workout/workout_test_helpers.dart';

void main() {
  group('Auth Sign Out & Account Switch Reset', () {
    late FakeAuthRepository authRepo;
    late MemoryWorkoutDraftRepository draftRepo;
    late FakeUserRepository userRepo;
    late ProviderContainer container;

    setUp(() {
      authRepo = FakeAuthRepository(
        initialUser: const AuthUser(id: 'user-old', email: 'old@levelup.vn'),
      );
      draftRepo = MemoryWorkoutDraftRepository();
      userRepo = FakeUserRepository(
        meResponse: const MeResponse(id: 'user-old', displayName: 'Người dùng cũ'),
      );

      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          workoutDraftRepositoryProvider.overrideWithValue(draftRepo),
          userRepositoryProvider.overrideWithValue(userRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'appSignOutRef resets onboardingController, deletes drafts, and signs out',
      () async {
        // 1. Điền thông tin vào onboardingController
        final ob = container.read(onboardingControllerProvider.notifier);
        ob.setDisplayName('Nguyễn Văn A');
        ob.selectGoal(UserGoal.build_muscle);
        ob.updateBodyInfo(heightCm: 175, startWeightKg: 70, goalWeightKg: 75);

        expect(
          container.read(onboardingControllerProvider).displayName,
          'Nguyễn Văn A',
        );
        expect(
          container.read(onboardingControllerProvider).goal,
          UserGoal.build_muscle,
        );

        // 2. Lưu một draft buổi tập của người cũ
        final setup = WorkoutSetup(
          session: planWith(const []).sessions.first,
          items: const [],
        );
        final workoutCtrl = container.read(activeWorkoutProvider.notifier);
        workoutCtrl.start(setup);
        final state = container.read(activeWorkoutProvider)!;

        final draft = WorkoutDraft(
          clientId: state.clientId,
          sessionId: state.session.id,
          stateJson: WorkoutDraft.encodeStateJson(state),
          updatedAt: DateTime.now(),
          status: 'active',
        );
        await draftRepo.saveDraft(draft);

        expect(await draftRepo.getActiveDraft(), isNotNull);
        expect(container.read(activeWorkoutProvider), isNotNull);

        // 3. Thực hiện sign out
        await appSignOutContainer(container);

        // 4. Kiểm tra auth đã signOut
        expect(authRepo.signOutCalled, isTrue);

        // 5. OnboardingController đã được reset về mặc định
        final resetState = container.read(onboardingControllerProvider);
        expect(resetState.displayName, isEmpty);
        expect(resetState.goal, isNull);
        expect(resetState.heightCm, isNull);
        expect(resetState.startWeightKg, isNull);

        // 6. Draft của người cũ đã bị xóa sạch
        expect(await draftRepo.getAllDrafts(), isEmpty);

        // 7. Active workout trong memory đã được dọn sạch
        expect(container.read(activeWorkoutProvider), isNull);
      },
    );

    test(
      'SettingsNotifier.logout calls appSignOutRef to clean old user data',
      () async {
        // Điền onboarding & tạo draft
        final ob = container.read(onboardingControllerProvider.notifier);
        ob.setDisplayName('Người dùng Cài đặt');
        await draftRepo.saveDraft(
          WorkoutDraft(
            clientId: 'client-draft-settings',
            sessionId: 'sess-1',
            stateJson: '{}',
            updatedAt: DateTime.now(),
            status: 'active',
          ),
        );

        final settingsNotifier =
            container.read(settingsControllerProvider.notifier);
        await settingsNotifier.logout();

        expect(authRepo.signOutCalled, isTrue);
        expect(
          container.read(onboardingControllerProvider).displayName,
          isEmpty,
        );
        expect(await draftRepo.getAllDrafts(), isEmpty);
      },
    );
  });
}
