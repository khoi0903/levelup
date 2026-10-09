import 'package:fitness_app/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:fitness_app/features/auth/domain/models/auth_user.dart';
import 'package:fitness_app/features/auth/presentation/controllers/auth_controller.dart';

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
import 'package:fitness_app/features/workout/data/repositories/memory_workout_draft_repository.dart';
import 'package:fitness_app/features/workout/domain/models/workout_draft.dart';
import 'package:fitness_app/features/workout/domain/models/workout_session_state.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HomeScreen', () {
    testWidgets(
      'Renders real user name, streak, and active workout card with skip button',
      (tester) async {
        final now = DateTime.now();
        final todayStr =
            '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

        final fakeUserRepo = FakeUserRepository(
          meResponse: MeResponse(
            id: 'u-1',
            displayName: 'Dinh Khoi',
            localDate: todayStr,
            streak: const UserStreak(
              currentWeeks: 4,
              bestWeeks: 8,
              freezesAvailable: 1,
            ),
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
              // Đã đăng nhập sẵn: luồng mở app giờ kiểm tra auth trước GET /me
              authRepositoryProvider.overrideWithValue(signedInAuth()),
              userRepositoryProvider.overrideWithValue(fakeUserRepo),
              planRepositoryProvider.overrideWithValue(fakePlanRepo),
              streakRepositoryProvider.overrideWithValue(fakeStreakRepo),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Check real user name in greeting
        expect(
          find.byKey(const ValueKey('home-greeting-text')),
          findsOneWidget,
        );
        expect(find.textContaining('Dinh Khoi'), findsWidgets);

        // Check streak pill
        expect(find.text('4 tuần'), findsOneWidget);

        // Check workout session
        expect(find.text('Ngực & Tay sau'), findsOneWidget);
        expect(find.text('Bắt đầu'), findsOneWidget);

        // Check skip button
        expect(
          find.byKey(const ValueKey('home-skip-report-button')),
          findsOneWidget,
        );

        // Tap skip button navigates to skip report
        await tester.ensureVisible(
          find.byKey(const ValueKey('home-skip-report-button')),
        );
        await tester.tap(find.byKey(const ValueKey('home-skip-report-button')));
        await tester.pumpAndSettle();

        expect(find.text('Không tập được hôm nay'), findsWidgets);
      },
    );

    testWidgets('Shows skeleton loading when user data is loading', (
      tester,
    ) async {
      final completer = Completer<MeResponse>();
      final slowUserRepo = FakeUserRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Đã đăng nhập sẵn: luồng mở app giờ kiểm tra auth trước GET /me
            authRepositoryProvider.overrideWithValue(signedInAuth()),
            userRepositoryProvider.overrideWithValue(slowUserRepo),
            userStatusFutureProvider.overrideWith((ref) => completer.future),
            streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
            planRepositoryProvider.overrideWithValue(FakePlanRepository()),
          ],
          child: const MaterialApp(home: HomeScreen()),
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

    testWidgets(
      'Ẩn nút "Không tập được hôm nay?" khi buổi hôm nay đã tập xong (status == completed)',
      (tester) async {
        final now = DateTime.now();
        final todayStr = localDateString(now);

        final fakePlan = PlanView(
          id: 'plan-completed',
          weekStart: '2026-09-28',
          status: 'active',
          targetSessions: 3,
          sessions: [
            SessionView(
              id: 'sess-today',
              scheduledDate: todayStr,
              scheduledTime: '07:00',
              title: 'Ngực & Tay sau',
              status: 'completed', // Đã tập xong
              durationMin: 25,
            ),
          ],
        );

        final fakeUserRepo = FakeUserRepository(
          meResponse: MeResponse(
            id: 'u-1',
            displayName: 'Khoi',
            localDate: todayStr,
          ),
        );

        final router = createAppRouter(initialLocation: '/home');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(signedInAuth()),
              userRepositoryProvider.overrideWithValue(fakeUserRepo),
              planRepositoryProvider.overrideWithValue(
                FakePlanRepository(planView: fakePlan),
              ),
              streakRepositoryProvider.overrideWithValue(
                FakeStreakRepository(),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Nút "Không tập được hôm nay?" phải bị ẩn
        expect(
          find.byKey(const ValueKey('home-skip-report-button')),
          findsNothing,
        );
        expect(find.text('Không tập được hôm nay?'), findsNothing);
        // Nút chính chuyển thành "Tập thêm"
        expect(find.text('Tập thêm'), findsOneWidget);
      },
    );

    testWidgets(
      'Ẩn nút "Không tập được hôm nay?" khi buổi ở ngày sau (scheduledDate != todayStr)',
      (tester) async {
        final now = DateTime.now();
        final todayStr = localDateString(now);
        final tomorrow = now.add(const Duration(days: 1));
        final tomorrowStr = localDateString(tomorrow);

        final fakePlan = PlanView(
          id: 'plan-future',
          weekStart: '2026-09-28',
          status: 'active',
          targetSessions: 3,
          sessions: [
            SessionView(
              id: 'sess-tomorrow',
              scheduledDate: tomorrowStr,
              scheduledTime: '07:00',
              title: 'Chân & Bụng',
              status: 'planned',
              durationMin: 25,
            ),
          ],
        );

        final fakeUserRepo = FakeUserRepository(
          meResponse: MeResponse(
            id: 'u-1',
            displayName: 'Khoi',
            localDate: todayStr,
          ),
        );

        final router = createAppRouter(initialLocation: '/home');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(signedInAuth()),
              userRepositoryProvider.overrideWithValue(fakeUserRepo),
              planRepositoryProvider.overrideWithValue(
                FakePlanRepository(planView: fakePlan),
              ),
              streakRepositoryProvider.overrideWithValue(
                FakeStreakRepository(),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Buổi ở ngày sau -> ẩn nút Không tập được hôm nay
        expect(
          find.byKey(const ValueKey('home-skip-report-button')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Hiện thẻ "Bạn đang tập dở ... Tiếp tục / Bỏ" khi có active draft < 12h, bấm Bỏ xóa draft',
      (tester) async {
        final now = DateTime.now();
        final todayStr = localDateString(now);

        final draftRepo = MemoryWorkoutDraftRepository();
        final sState = WorkoutSessionState(
          session: SessionView(
            id: 'sess-active',
            scheduledDate: todayStr,
            scheduledTime: '07:00',
            title: 'Cardio Buổi Sáng',
            status: 'planned',
            durationMin: 20,
          ),
          items: const [
            WorkoutPlanItem(
              exerciseId: 'ex-cardio',
              nameVi: 'Jumping Jack',
              sets: 3,
              reps: 20,
            ),
          ],
          clientId: 'client-active-draft-999',
          startedAt: now.subtract(const Duration(minutes: 15)),
          exerciseIndex: 0,
          setNumber: 2,
        );

        await draftRepo.saveDraft(
          WorkoutDraft(
            clientId: sState.clientId,
            sessionId: sState.session.id,
            stateJson: WorkoutDraft.encodeStateJson(sState),
            updatedAt: now.subtract(const Duration(minutes: 5)),
            status: 'active',
          ),
        );

        final router = createAppRouter(initialLocation: '/home');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(signedInAuth()),
              userRepositoryProvider.overrideWithValue(
                FakeUserRepository(
                  meResponse: MeResponse(
                    id: 'u-1',
                    displayName: 'Khoi',
                    localDate: todayStr,
                  ),
                ),
              ),
              planRepositoryProvider.overrideWithValue(FakePlanRepository()),
              streakRepositoryProvider.overrideWithValue(
                FakeStreakRepository(),
              ),
              workoutDraftRepositoryProvider.overrideWithValue(draftRepo),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Thẻ đang tập dở hiện lên
        expect(
          find.byKey(const ValueKey('home-active-draft-card')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Bạn đang tập dở Cardio Buổi Sáng'),
          findsOneWidget,
        );
        expect(find.text('Tiếp tục'), findsOneWidget);
        expect(find.text('Bỏ'), findsOneWidget);

        // Bấm Bỏ -> draft bị xóa khỏi repo và thẻ biến mất
        await tester.tap(
          find.byKey(const ValueKey('home-active-draft-discard-button')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('home-active-draft-card')),
          findsNothing,
        );
        expect(await draftRepo.getActiveDraft(), isNull);
      },
    );
    testWidgets(
      'Chỉ còn buổi đã bị chốt bỏ: nút là "Tập thêm", không "Bắt đầu"',
      (tester) async {
        final now = DateTime.now();
        final todayStr = localDateString(now);
        final yesterdayStr = localDateString(
          now.subtract(const Duration(days: 1)),
        );
        final fakePlan = PlanView(
          id: 'plan-skipped',
          weekStart: '2026-09-28',
          status: 'active',
          targetSessions: 2,
          sessions: [
            SessionView(
              id: 'sess-skipped',
              scheduledDate: yesterdayStr,
              scheduledTime: '06:00',
              title: 'Toàn thân cơ bản',
              status: 'skipped',
              durationMin: 15,
              items: const [
                ItemView(
                  exerciseId: 'ex-1',
                  nameVi: 'Squat',
                  sets: 2,
                  reps: 10,
                ),
              ],
            ),
          ],
        );
        final router = createAppRouter(initialLocation: '/home');
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(signedInAuth()),
              userRepositoryProvider.overrideWithValue(
                FakeUserRepository(
                  meResponse: MeResponse(
                    id: 'u-1',
                    displayName: 'Khoi',
                    localDate: todayStr,
                  ),
                ),
              ),
              planRepositoryProvider.overrideWithValue(
                FakePlanRepository(planView: fakePlan),
              ),
              streakRepositoryProvider.overrideWithValue(
                FakeStreakRepository(),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Tập thêm'), findsWidgets);
        expect(find.text('Bắt đầu'), findsNothing);
      },
    );
  });

  for (final demo in [false, true]) {
    testWidgets('Bấm 5 lần vào lời chào: demoEnabled=$demo', (tester) async {
      final router = createAppRouter(initialLocation: '/home');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(signedInAuth()),
            userRepositoryProvider.overrideWithValue(
              FakeUserRepository(
                meResponse: MeResponse(
                  id: 'u-1',
                  displayName: 'Khoi',
                  localDate: localDateString(DateTime.now()),
                  demoEnabled: demo,
                ),
              ),
            ),
            planRepositoryProvider.overrideWithValue(FakePlanRepository()),
            streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const ValueKey('home-header-title-tap')));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(
        find.text('Giả lập Demo'),
        demo ? findsOneWidget : findsNothing,
        reason: 'chỉ tài khoản được máy chủ cho phép mới mở màn Demo',
      );
    });
  }

  test('Lời chào theo giờ', () {
    expect(greetingFor(DateTime(2026, 10, 9, 9, 11)), 'Chào buổi sáng');
    expect(greetingFor(DateTime(2026, 10, 9, 12, 0)), 'Chào buổi trưa');
    expect(greetingFor(DateTime(2026, 10, 9, 15, 0)), 'Chào buổi chiều');
    expect(greetingFor(DateTime(2026, 10, 9, 19, 30)), 'Chào buổi tối');
    expect(greetingFor(DateTime(2026, 10, 9, 23, 30)), 'Khuya rồi');
  });
}

FakeAuthRepository signedInAuth() => FakeAuthRepository(
  initialUser: const AuthUser(id: 'test-user', email: 'test@levelup.vn'),
);
