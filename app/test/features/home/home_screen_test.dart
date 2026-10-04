import 'dart:async';
import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/core/widgets/app_skeleton.dart';
import 'package:fitness_app/features/home/presentation/screens/home_screen.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_plan_repository.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/streak/data/repositories/fake_streak_repository.dart';
import 'package:fitness_app/features/streak/domain/models/streak_models.dart';
import 'package:fitness_app/features/streak/presentation/controllers/streak_controller.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('Renders real user name, streak, and active workout card with skip button', (tester) async {
      final now = DateTime.now();
      final todayStr = '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final fakeUserRepo = FakeUserRepository(
        meResponse: MeResponse(
          id: 'u-1',
          displayName: 'Dinh Khoi',
          localDate: todayStr,
          streak: const UserStreak(currentWeeks: 4, bestWeeks: 8, freezesAvailable: 1),
        ),
      );

      final fakeStreakRepo = FakeStreakRepository(
        initialStreak: const StreakView(
          currentWeeks: 4,
          bestWeeks: 8,
          freezesAvailable: 1,
          weeks: [],
        ),
      );

      final fakePlan = PlanView(
        id: 'plan-1',
        weekStart: '2026-09-28',
        status: 'active',
        targetSessions: 3,
        sessions: [
          SessionView(
            id: 'sess-today',
            scheduledDate: todayStr,
            scheduledTime: '07:00',
            title: 'Ngực & Tay sau',
            status: 'planned',
            durationMin: 25,
            items: const [
              ItemView(
                exerciseId: 'ex-1',
                nameVi: 'Hít đất',
                sets: 3,
                reps: 12,
              ),
            ],
          ),
        ],
      );

      final fakePlanRepo = FakePlanRepository(planView: fakePlan);

      final router = createAppRouter(initialLocation: '/home');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
            planRepositoryProvider.overrideWithValue(fakePlanRepo),
            streakRepositoryProvider.overrideWithValue(fakeStreakRepo),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check real user name in greeting
      expect(find.byKey(const ValueKey('home-greeting-text')), findsOneWidget);
      expect(find.textContaining('Dinh Khoi'), findsWidgets);

      // Check streak pill
      expect(find.text('4 tuần'), findsOneWidget);

      // Check workout session
      expect(find.text('Ngực & Tay sau'), findsOneWidget);
      expect(find.text('Bắt đầu'), findsOneWidget);

      // Check skip button
      expect(find.byKey(const ValueKey('home-skip-report-button')), findsOneWidget);

      // Tap skip button navigates to skip report
      await tester.ensureVisible(find.byKey(const ValueKey('home-skip-report-button')));
      await tester.tap(find.byKey(const ValueKey('home-skip-report-button')));
      await tester.pumpAndSettle();

      expect(find.text('Không tập được hôm nay'), findsWidgets);
    });

    testWidgets('Shows skeleton loading when user data is loading', (tester) async {
      final completer = Completer<MeResponse>();
      final slowUserRepo = FakeUserRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(slowUserRepo),
            userStatusFutureProvider.overrideWith((ref) => completer.future),
            streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
            planRepositoryProvider.overrideWithValue(FakePlanRepository()),
          ],
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      // Pump 1 frame to start loading
      await tester.pump();

      // Skeleton should be rendered
      expect(find.byType(HomeScreenSkeleton), findsOneWidget);

      // Complete future
      completer.complete(const MeResponse(id: 'u-1', displayName: 'Dinh Khoi'));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreenSkeleton), findsNothing);
      expect(find.textContaining('Dinh Khoi'), findsWidgets);
    });
  });
}
