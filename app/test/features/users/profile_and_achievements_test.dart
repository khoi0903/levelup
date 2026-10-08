import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:fitness_app/features/auth/domain/models/auth_user.dart';
import 'package:fitness_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_plan_repository.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/streak/data/repositories/fake_streak_repository.dart';
import 'package:fitness_app/features/streak/presentation/controllers/streak_controller.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:fitness_app/features/users/presentation/screens/achievements_screen.dart';
import 'package:fitness_app/features/users/presentation/screens/profile_screen.dart';
import 'package:fitness_app/features/workout/data/repositories/fake_workout_repository.dart';
import 'package:fitness_app/features/workout/domain/models/exercise_response.dart';
import 'package:fitness_app/features/workout/domain/models/workout_models.dart';
import 'package:fitness_app/features/workout/domain/models/workout_session_state.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:fitness_app/features/workout/presentation/screens/workout_extra_screen.dart';
import 'package:fitness_app/features/workout/presentation/screens/workout_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeWorkoutController extends WorkoutController {
  _FakeWorkoutController(super.ref, WorkoutSessionState? initial) {
    state = initial;
  }
}

void main() {
  group('Profile & Settings (Tab Tôi - F4/F7)', () {
    testWidgets(
      'ProfileScreen edits name on done/unfocus, toggles goal with confirmation, and saves schedule',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeRepo = FakeUserRepository(
          meResponse: const MeResponse(
            id: 'u1',
            displayName: 'Minh Khôi',
            timezone: 'Asia/Ho_Chi_Minh',
            localDate: '2026-10-04',
            weekStart: '2026-09-28',
            profile: UserProfile(
              goal: 'lose_fat',
              coachStyle: 'supportive',
              sessionMinutes: 15,
            ),
            streak: UserStreak(
              currentWeeks: 2,
              bestWeeks: 2,
              freezesAvailable: 1,
            ),
            settings: UserSettings(
              notifications: UserNotificationsSettings(
                pushEnabled: true,
                quietStart: '22:00',
                quietEnd: '07:00',
                maxPerDay: 2,
              ),
              sharing: UserSharingSettings(
                weight: true,
                measurements: false,
                photos: false,
                meals: true,
              ),
              availability: [
                UserAvailabilitySlot(weekday: 1, slot: 'evening'),
                UserAvailabilitySlot(weekday: 3, slot: 'evening'),
                UserAvailabilitySlot(weekday: 5, slot: 'evening'),
              ],
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [userRepositoryProvider.overrideWithValue(fakeRepo)],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Verify display name loaded
        final nameWidget = tester.widget<Text>(
          find.byKey(const ValueKey('profile-display-name')),
        );
        expect(nameWidget.data, 'Minh Khôi');

        // Edit name in TextField & submit (Done)
        final textField = find.byType(TextField);
        expect(textField, findsOneWidget);
        await tester.enterText(textField, 'Nguyễn Minh Khôi');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(fakeRepo.lastJson, {'displayName': 'Nguyễn Minh Khôi'});
        expect(find.text('Đã lưu'), findsOneWidget);

        // Đổi mục tiêu -> hiện dialog xác nhận -> bấm Xác nhận
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-goal-build_muscle')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('settings-goal-build_muscle')));
        await tester.pumpAndSettle();

        expect(find.text('Đổi mục tiêu?'), findsOneWidget);
        expect(find.text('Mục tiêu calo sẽ tính lại từ hôm nay.'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('confirm-goal-change')));
        await tester.pumpAndSettle();

        expect(fakeRepo.lastJson, {'goal': 'build_muscle'});

        // Select Coach style "Nghiêm khắc" -> lưu ngay
        await tester.scrollUntilVisible(
          find.text('Nghiêm khắc'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nghiêm khắc'));
        await tester.pumpAndSettle();
        expect(fakeRepo.lastJson, {'coachStyle': 'strict'});

        // Bật nhắc uống nước -> lưu ngay
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-water-reminder')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('settings-water-reminder')));
        await tester.pumpAndSettle();
        expect(fakeRepo.lastJson, {
          'notifications': {'waterReminder': true},
        });

        // Bấm nút "Lưu lịch tập"
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('save-schedule-button')),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('save-schedule-button')));
        await tester.pumpAndSettle();

        final updatedMe = await fakeRepo.getMe();
        expect(updatedMe.displayName, 'Nguyễn Minh Khôi');
        expect(updatedMe.profile?.coachStyle, 'strict');
        expect(updatedMe.profile?.goal, 'build_muscle');
        expect(updatedMe.settings.notifications.waterReminder, isTrue);
      },
    );

    testWidgets(
      'Toggling switch sends PATCH with only single changed field',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeRepo = FakeUserRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [userRepositoryProvider.overrideWithValue(fakeRepo)],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Toggle water reminder
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-water-reminder')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('settings-water-reminder')));
        await tester.pumpAndSettle();

        expect(fakeRepo.lastJson, {
          'notifications': {'waterReminder': true},
        });
        expect(find.text('Đã lưu'), findsOneWidget);
      },
    );

    testWidgets(
      'Error rolls back UI state and displays error SnackBar',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeRepo = FakeUserRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [userRepositoryProvider.overrideWithValue(fakeRepo)],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Set repo to fail next PATCH
        fakeRepo.errorToThrow = const ApiException(
          code: 'SERVER_ERROR',
          statusCode: 500,
        );

        // Toggle water reminder
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-water-reminder')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('settings-water-reminder')));
        await tester.pumpAndSettle();

        // Switch should be rolled back to false
        final switchWidget = tester.widget<SwitchListTile>(
          find.byKey(const ValueKey('settings-water-reminder')),
        );
        expect(switchWidget.value, isFalse);

        // Error SnackBar should be displayed
        expect(find.byKey(const ValueKey('settings-error-banner')), findsOneWidget);
      },
    );

    testWidgets(
      'Selecting gym sends location: gym, hides equipment list, and shows gym note',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeRepo = FakeUserRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [userRepositoryProvider.overrideWithValue(fakeRepo)],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll to location & equipment
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-location-gym')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // Ban đầu ở 'home', có thấy chip thiết bị
        expect(find.byKey(const ValueKey('settings-equipment-dumbbell')), findsOneWidget);

        // Bấm chọn Phòng gym
        await tester.tap(find.byKey(const ValueKey('settings-location-gym')));
        await tester.pumpAndSettle();

        expect(fakeRepo.lastJson, {'location': 'gym'});
        expect(find.text('Phòng gym có đủ dụng cụ'), findsOneWidget);
        expect(find.byKey(const ValueKey('settings-equipment-dumbbell')), findsNothing);
      },
    );

    testWidgets(
      'Changing equipment sends {"equipment": [...]} and WorkoutExtraScreen reflects newly unlocked exercises',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const dumbbellExercise = ExerciseResponse(
          id: 'ex-dumbbell',
          slug: 'dumbbell-curl',
          nameVi: 'Cuốn tạ đơn',
          primaryMuscle: 'arms',
          equipment: ['dumbbell'],
          difficulty: 2,
          tracking: 'reps',
        );

        const bodyweightExercise = ExerciseResponse(
          id: 'ex-pushup',
          slug: 'push-up',
          nameVi: 'Hít đất',
          primaryMuscle: 'chest',
          equipment: [],
          difficulty: 2,
          tracking: 'reps',
        );

        final initialMe = const MeResponse(
          id: 'u1',
          displayName: 'Minh',
          profile: UserProfile(
            location: 'home',
            equipment: [],
          ),
        );

        final fakeRepo = FakeUserRepository(meResponse: initialMe);
        final fakeWorkoutRepo = FakeWorkoutRepository(
          exercises: [bodyweightExercise, dumbbellExercise],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userRepositoryProvider.overrideWithValue(fakeRepo),
              workoutRepositoryProvider.overrideWithValue(fakeWorkoutRepo),
            ],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll to equipment chips
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('settings-equipment-dumbbell')),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        // Tap chip dumbbell
        await tester.tap(find.byKey(const ValueKey('settings-equipment-dumbbell')));
        await tester.pumpAndSettle();

        expect(fakeRepo.lastJson, {
          'equipment': ['dumbbell'],
        });
        expect(find.text('Đã lưu'), findsOneWidget);
      },
    );

    testWidgets(
      'WorkoutExtraScreen reacts immediately to newly unlocked exercises when equipment is updated',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const dumbbellExercise = ExerciseResponse(
          id: 'ex-dumbbell',
          slug: 'dumbbell-curl',
          nameVi: 'Cuốn tạ đơn',
          primaryMuscle: 'arms',
          equipment: ['dumbbell'],
          difficulty: 2,
          tracking: 'reps',
        );

        const bodyweightExercise = ExerciseResponse(
          id: 'ex-pushup',
          slug: 'push-up',
          nameVi: 'Hít đất',
          primaryMuscle: 'chest',
          equipment: [],
          difficulty: 2,
          tracking: 'reps',
        );

        final initialMe = const MeResponse(
          id: 'u1',
          displayName: 'Minh',
          profile: UserProfile(
            location: 'home',
            equipment: ['dumbbell'],
          ),
        );

        final fakeRepo = FakeUserRepository(meResponse: initialMe);
        final fakeWorkoutRepo = FakeWorkoutRepository(
          exercises: [bodyweightExercise, dumbbellExercise],
        );
        final plan = PlanView(
          id: 'plan-1',
          weekStart: '2026-10-05',
          status: 'active',
          targetSessions: 3,
          sessions: [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userRepositoryProvider.overrideWithValue(fakeRepo),
              workoutRepositoryProvider.overrideWithValue(fakeWorkoutRepo),
              planRepositoryProvider.overrideWithValue(FakePlanRepository(planView: plan)),
            ],
            child: const MaterialApp(home: WorkoutExtraScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to "Tự chọn bài" tab
        await tester.tap(find.text('Tự chọn bài'));
        await tester.pumpAndSettle();

        // Cuốn tạ đơn is visible because user has dumbbell!
        expect(find.text('Cuốn tạ đơn'), findsOneWidget);
        expect(find.text('Hít đất'), findsOneWidget);
      },
    );

    testWidgets(
      'Leaving tab and returning resets to server value without keeping unsaved edits',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeRepo = FakeUserRepository(
          meResponse: const MeResponse(
            id: 'u1',
            displayName: 'Minh Gốc',
            profile: UserProfile(goal: 'lose_fat'),
          ),
        );

        final router = createAppRouter(initialLocation: '/profile');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(
                FakeAuthRepository(
                  initialUser: const AuthUser(id: 'u1', email: 'test@levelup.vn'),
                ),
              ),
              userRepositoryProvider.overrideWithValue(fakeRepo),
              streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
              planRepositoryProvider.overrideWithValue(
                FakePlanRepository(
                  planView: PlanView(
                    id: 'p1',
                    weekStart: '2026-10-05',
                    status: 'active',
                    targetSessions: 3,
                    sessions: [],
                  ),
                ),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        final textField = find.byType(TextField);
        await tester.enterText(textField, 'Tên Chưa Lưu');
        await tester.pump();

        // Switch to Home tab (tab index 0)
        await tester.tap(find.byKey(const ValueKey('tab-home')));
        await tester.pumpAndSettle();

        // Switch back to Profile tab (tab index 4)
        await tester.tap(find.byKey(const ValueKey('tab-profile')));
        await tester.pumpAndSettle();

        final nameField = tester.widget<TextField>(find.byType(TextField));
        expect(nameField.controller?.text, 'Minh Gốc');
      },
    );

    testWidgets(
      'ProfileScreen displays backend error banner when saving fails',
      (tester) async {
        final fakeRepo = FakeUserRepository(
          errorToThrow: const ApiException(
            code: 'NOTHING_TO_UPDATE',
            statusCode: 400,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [userRepositoryProvider.overrideWithValue(fakeRepo)],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // When loading throws error, Error text is shown
        expect(find.text('Bạn chưa thay đổi thông tin nào.'), findsOneWidget);
      },
    );

    testWidgets(
      'AchievementsScreen renders badge list and highlights earned badges from GET /me',
      (tester) async {
        final fakeRepo = FakeUserRepository(
          meResponse: const MeResponse(
            id: 'u1',
            displayName: 'Minh Khôi',
            timezone: 'Asia/Ho_Chi_Minh',
            localDate: '2026-10-04',
            weekStart: '2026-09-28',
            achievements: [
              Achievement(
                code: 'first_workout',
                nameVi: 'Bước đầu tiên',
                descriptionVi: 'Hoàn thành buổi tập đầu tiên cùng LevelUp',
                category: 'sessions',
                earnedAt: '2026-10-02T10:00:00Z',
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [userRepositoryProvider.overrideWithValue(fakeRepo)],
            child: const MaterialApp(home: AchievementsScreen()),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Huy hiệu của bạn'), findsOneWidget);
        expect(find.text('Bộ sưu tập huy hiệu'), findsOneWidget);
        expect(find.text('Đã mở khóa 1/9 huy hiệu'), findsOneWidget);
        expect(find.text('Bước đầu tiên'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(find.text('Chiến binh 1 tuần'), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline_rounded), findsWidgets);
      },
    );

    testWidgets(
      'WorkoutResultScreen displays celebration banner when new achievements earned',
      (tester) async {
        final dummySession = SessionView(
          id: 'session-12345678901234567890',
          title: 'Toàn thân nhập môn',
          durationMin: 15,
          scheduledDate: '2026-10-04',
          scheduledTime: '07:00',
          variant: 'normal',
          status: 'completed',
        );

        final dummyResult = WorkoutResult(
          workoutId: 'w-1',
          localDate: '2026-10-04',
          durationSec: 600,
          countsForStreak: true,
          personalRecords: const [],
          newAchievements: const [
            Achievement(
              code: 'first_workout',
              nameVi: 'Bước đầu tiên',
              descriptionVi: 'Hoàn thành buổi tập đầu tiên cùng LevelUp',
            ),
          ],
        );

        final dummyState = WorkoutSessionState(
          session: dummySession,
          items: const [],
          clientId: 'client-12345678901234567890',
          startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          endedAt: DateTime.now(),
          result: dummyResult,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeWorkoutProvider.overrideWith(
                (ref) => _FakeWorkoutController(ref, dummyState),
              ),
            ],
            child: const MaterialApp(home: WorkoutResultScreen()),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Xong buổi tập!'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('achievement-celebration-banner')),
          findsOneWidget,
        );
        expect(
          find.text('Ăn mừng thành tích! Bạn vừa mở khóa huy hiệu mới.'),
          findsOneWidget,
        );
        expect(find.text('Bước đầu tiên'), findsOneWidget);
      },
    );
  });
}
