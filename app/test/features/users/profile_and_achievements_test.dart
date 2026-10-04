import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:fitness_app/features/users/presentation/screens/achievements_screen.dart';
import 'package:fitness_app/features/users/presentation/screens/profile_screen.dart';
import 'package:fitness_app/features/workout/domain/models/workout_models.dart';
import 'package:fitness_app/features/workout/domain/models/workout_session_state.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
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
      'ProfileScreen loads user, edits name & settings, and saves successfully',
      (tester) async {
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

        // Edit name in TextField
        final textField = find.byType(TextField);
        expect(textField, findsOneWidget);
        await tester.enterText(textField, 'Nguyễn Minh Khôi');
        await tester.pumpAndSettle();

        // Select Coach style "Nghiêm khắc"
        await tester.ensureVisible(find.text('Nghiêm khắc'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nghiêm khắc'));
        await tester.pumpAndSettle();

        // Scroll to reveal availability
        await tester.ensureVisible(
          find.text('Đổi lịch rảnh chỉ áp dụng từ tuần sau.'),
        );
        await tester.pumpAndSettle();

        // Verify availability note is displayed
        expect(
          find.text('Đổi lịch rảnh chỉ áp dụng từ tuần sau.'),
          findsOneWidget,
        );

        // Toggle weekday "T3" (weekday 2)
        await tester.ensureVisible(find.text('T3'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('T3'));
        await tester.pumpAndSettle();

        // Scroll down to tap "Lưu cài đặt"
        await tester.drag(find.byType(ListView), const Offset(0, -1000));
        await tester.pumpAndSettle();

        final saveButton = find.text('Lưu cài đặt');
        expect(saveButton, findsOneWidget);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        // Scroll back up to see success banner
        await tester.drag(find.byType(ListView), const Offset(0, 1000));
        await tester.pumpAndSettle();

        // Verify success message
        expect(
          find.byKey(const ValueKey('settings-success-banner')),
          findsOneWidget,
        );
        expect(find.text('Đã lưu cài đặt thành công!'), findsOneWidget);

        // Verify repo was updated
        final updatedMe = await fakeRepo.getMe();
        expect(updatedMe.displayName, 'Nguyễn Minh Khôi');
        expect(updatedMe.profile?.coachStyle, 'strict');
        expect(
          updatedMe.settings.availability
              .map((s) => s.weekday)
              .toSet()
              .contains(2),
          isTrue,
        );
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
