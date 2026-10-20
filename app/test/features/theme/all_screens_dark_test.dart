import 'package:fitness_app/features/activity/data/repositories/api_activity_repository.dart';
import 'package:fitness_app/features/activity/data/repositories/fake_activity_repository.dart';
import 'package:fitness_app/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:fitness_app/features/auth/domain/models/auth_user.dart';
import 'package:fitness_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitness_app/features/buddies/data/repositories/fake_buddy_repository.dart';
import 'package:fitness_app/features/buddies/presentation/controllers/buddy_controller.dart';
import 'package:fitness_app/features/checkins/data/repositories/fake_checkin_repository.dart';
import 'package:fitness_app/features/checkins/presentation/controllers/checkin_controller.dart';
import 'package:fitness_app/features/demo/data/repositories/fake_demo_repository.dart';
import 'package:fitness_app/features/demo/presentation/controllers/demo_controller.dart';
import 'package:fitness_app/features/nutrition/data/repositories/fake_nutrition_repository.dart';
import 'package:fitness_app/features/nutrition/presentation/controllers/nutrition_controller.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_onboarding_repository.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/progress/data/repositories/fake_progress_repository.dart';
import 'package:fitness_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:fitness_app/features/reviews/data/repositories/fake_review_repository.dart';
import 'package:fitness_app/features/reviews/presentation/controllers/review_controller.dart';
import 'package:fitness_app/features/skip_report/data/repositories/fake_skip_report_repository.dart';
import 'package:fitness_app/features/skip_report/presentation/controllers/skip_report_controller.dart';
import 'package:fitness_app/features/streak/data/repositories/fake_streak_repository.dart';
import 'package:fitness_app/features/streak/presentation/controllers/streak_controller.dart';
import 'package:fitness_app/features/workout/data/camera/rep_counting_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../workout/workout_test_helpers.dart';
import 'readability.dart';

/// Toàn app ở chế độ tối, dữ liệu giả cho mọi màn.
WorkoutHarness darkHarness({RepSessionFactory? factory}) => WorkoutHarness(
  plan: planWith(const [
    ItemView(exerciseId: squatId, nameVi: 'Squat', sets: 2, reps: 10),
    ItemView(exerciseId: gobletId, nameVi: 'Goblet squat', sets: 2, reps: 10),
  ]),
  factory: factory,
  themeMode: ThemeMode.dark,
  extraOverrides: [
    authRepositoryProvider.overrideWithValue(
      FakeAuthRepository(
        initialUser: const AuthUser(id: 'test-user', email: 'test@levelup.vn'),
      ),
    ),
    buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
    checkinRepositoryProvider.overrideWithValue(FakeCheckinRepository()),
    demoRepositoryProvider.overrideWithValue(FakeDemoRepository()),
    nutritionRepositoryProvider.overrideWithValue(FakeNutritionRepository()),
    onboardingRepositoryProvider.overrideWithValue(FakeOnboardingRepository()),
    progressRepositoryProvider.overrideWithValue(FakeProgressRepository()),
    reviewRepositoryProvider.overrideWithValue(FakeReviewRepository()),
    skipReportRepositoryProvider.overrideWithValue(FakeSkipReportRepository()),
    streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
    activityRepositoryProvider.overrideWithValue(FakeActivityRepository()),
  ],
);

const routes = [
  '/home',
  '/workout',
  '/workout/$sessionId',
  '/workout/extra',
  '/coach',
  '/nutrition',
  '/nutrition/add',
  '/profile',
  '/checkin',
  '/streak',
  '/streak/week/2026-10-05',
  '/demo',
  '/skip-report?sessionId=$sessionId',
  '/buddy',
  '/reviews/latest',
  '/achievements',
  '/progress',
  '/progress/measurements',
  '/activity',
  '/pro',
  '/referrals',
  '/login',
  '/onboarding/goal',
  '/onboarding/body',
  '/onboarding/training',
  '/onboarding/schedule',
  '/onboarding/why',
  '/onboarding/coach',
  '/onboarding/plan',
  '/onboarding/notify',
  '/onboarding/start',
];

/// Font giả trong test (Ahem) rộng hơn font thật nhiều nên hay báo tràn hàng; test này chỉ xét màu.
Future<void> ignoringOverflow(Future<void> Function() body) async {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = original;
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final route in routes) {
    testWidgets('chế độ tối đọc được: $route', (tester) async {
      await ignoringOverflow(() async {
        await darkHarness().pump(tester, route);
        await scrollAndCheckReadable(tester, where: route);
      });
    });
  }

  testWidgets('chế độ tối đọc được: buổi tập đang chạy và màn camera', (
    tester,
  ) async {
    final h = darkHarness(
      factory: FakeRepSessionFactory(
        const RepSnapshot(
          status: RepCountingStatus.running,
          averageConfidence: 0.9,
        ),
      ),
    );
    await h.pump(tester, '/workout/$sessionId');
    await tapText(tester, 'Bắt đầu');
    await scrollAndCheckReadable(tester, where: 'workout/active');

    await tapText(tester, 'Đếm bằng camera');
    expectReadableText(tester, where: 'camera: chuẩn bị');
    await tapText(tester, 'Tôi đã sẵn sàng');
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expectReadableText(tester, where: 'camera: đang đếm');
  });
}
