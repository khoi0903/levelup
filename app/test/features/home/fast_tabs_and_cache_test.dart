import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/app/theme.dart';
import 'package:fitness_app/core/utils/fast_cache.dart';
import 'package:fitness_app/core/widgets/app_skeleton.dart';
import 'package:fitness_app/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:fitness_app/features/auth/domain/models/auth_user.dart';
import 'package:fitness_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitness_app/features/buddies/data/repositories/fake_buddy_repository.dart';
import 'package:fitness_app/features/buddies/presentation/controllers/buddy_controller.dart';
import 'package:fitness_app/features/coach/data/repositories/fake_coach_repository.dart';
import 'package:fitness_app/features/coach/presentation/controllers/coach_controller.dart';
import 'package:fitness_app/features/home/presentation/controllers/home_controller.dart';
import 'package:fitness_app/features/nutrition/data/repositories/fake_nutrition_repository.dart';
import 'package:fitness_app/features/nutrition/presentation/controllers/nutrition_controller.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_plan_repository.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/streak/data/repositories/fake_streak_repository.dart';
import 'package:fitness_app/features/streak/domain/models/streak_models.dart';
import 'package:fitness_app/features/streak/presentation/controllers/streak_controller.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';

class CountingUserRepository extends FakeUserRepository {
  int getMeCallCount = 0;

  CountingUserRepository({super.meResponse});

  @override
  Future<MeResponse> getMe() async {
    getMeCallCount++;
    return super.getMe();
  }
}

class CountingPlanRepository extends FakePlanRepository {
  int getPlanCallCount = 0;

  CountingPlanRepository({super.planView});

  @override
  Future<PlanView> getCurrentPlan() async {
    getPlanCallCount++;
    return super.getCurrentPlan();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testUid = 'user-fast-cache';
  const testUser = AuthUser(id: testUid, email: 'fast@levelup.vn');

  const demoMe = MeResponse(
    id: testUid,
    displayName: 'Nguyễn Văn Nhanh',
    localDate: '2026-10-12',
    weekStart: '2026-10-12',
    streak: UserStreak(currentWeeks: 2, bestWeeks: 4, freezesAvailable: 1),
  );

  const demoPlan = PlanView(
    id: 'plan-1',
    weekStart: '2026-10-12',
    status: 'active',
    targetSessions: 3,
    sessions: [
      SessionView(
        id: 'session-1',
        title: 'Buổi 1: Toàn thân',
        scheduledDate: '2026-10-12',
        scheduledTime: '07:00',
        durationMin: 30,
        status: 'open',
        items: [
          ItemView(
            exerciseId: 'squat',
            nameVi: 'Squat',
            sets: 3,
            reps: 10,
          ),
        ],
      ),
      SessionView(
        id: 'session-2',
        title: 'Buổi 2: Thượng thân',
        scheduledDate: '2026-10-14',
        scheduledTime: '07:00',
        durationMin: 30,
        status: 'open',
      ),
      SessionView(
        id: 'session-3',
        title: 'Buổi 3: Hạ thân',
        scheduledDate: '2026-10-16',
        scheduledTime: '07:00',
        durationMin: 30,
        status: 'open',
      ),
    ],
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await FastCache.clearAll();
  });

  group('Chuyển trang nhanh, Cache 5 phút & Khởi động tức thì', () {
    testWidgets(
      'Vào Trang chủ -> sang tab khác -> quay lại trong 5 phút KHÔNG gọi lại API và không hiện spinner',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final countingUserRepo = CountingUserRepository(meResponse: demoMe);
        final countingPlanRepo = CountingPlanRepository(planView: demoPlan);
        final fakeAuthRepo = FakeAuthRepository(initialUser: testUser);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(countingUserRepo),
            planRepositoryProvider.overrideWithValue(countingPlanRepo),
            streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
            buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
            coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
            nutritionRepositoryProvider.overrideWithValue(FakeNutritionRepository()),
          ],
        );
        addTearDown(container.dispose);

        final router = createAppRouter(initialLocation: '/home');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Trang chủ đã hiện dữ liệu
        expect(find.textContaining('Nguyễn Văn Nhanh'), findsOneWidget);
        expect(countingUserRepo.getMeCallCount, equals(1));
        expect(countingPlanRepo.getPlanCallCount, equals(1));

        // Chuyển sang tab "Tôi"
        final tabProfile = find.byKey(const ValueKey('tab-profile'));
        expect(tabProfile, findsOneWidget);
        await tester.tap(tabProfile);
        await tester.pumpAndSettle();

        // Chuyển về lại tab "Trang chủ"
        final tabHome = find.byKey(const ValueKey('tab-home'));
        expect(tabHome, findsOneWidget);
        await tester.tap(tabHome);
        await tester.pumpAndSettle();

        // KHÔNG gọi lại API do còn hạn cache 5 phút
        expect(countingUserRepo.getMeCallCount, equals(1));
        expect(countingPlanRepo.getPlanCallCount, equals(1));

        // Không xuất hiện skeleton hay full-screen spinner
        expect(find.byType(HomeScreenSkeleton), findsNothing);
        expect(find.textContaining('Nguyễn Văn Nhanh'), findsOneWidget);
      },
    );

    testWidgets(
      'Sau ref.invalidate(...) thì gọi lại API',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final countingUserRepo = CountingUserRepository(meResponse: demoMe);
        final countingPlanRepo = CountingPlanRepository(planView: demoPlan);
        final fakeAuthRepo = FakeAuthRepository(initialUser: testUser);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(countingUserRepo),
            planRepositoryProvider.overrideWithValue(countingPlanRepo),
            streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
            buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
            coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
            nutritionRepositoryProvider.overrideWithValue(FakeNutritionRepository()),
          ],
        );
        addTearDown(container.dispose);

        final router = createAppRouter(initialLocation: '/home');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(countingUserRepo.getMeCallCount, equals(1));
        expect(countingPlanRepo.getPlanCallCount, equals(1));

        // Invalidate các provider
        container.invalidate(userStatusFutureProvider);
        container.invalidate(homePlanProvider);
        await tester.pumpAndSettle();

        // Gọi lại API sau invalidate
        expect(countingUserRepo.getMeCallCount, equals(2));
        expect(countingPlanRepo.getPlanCallCount, equals(2));
      },
    );

    testWidgets(
      'Lưu buổi tập xong màn chính thấy số buổi mới (invalidate sau khi ghi)',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final planWith1Done = PlanView(
          id: demoPlan.id,
          weekStart: demoPlan.weekStart,
          status: demoPlan.status,
          targetSessions: demoPlan.targetSessions,
          sessions: [
            SessionView(
              id: 'session-1',
              title: 'Buổi 1: Toàn thân',
              scheduledDate: '2026-10-12',
              scheduledTime: '07:00',
              durationMin: 30,
              status: 'completed',
            ),
            SessionView(
              id: 'session-2',
              title: 'Buổi 2: Thượng thân',
              scheduledDate: '2026-10-14',
              scheduledTime: '07:00',
              durationMin: 30,
              status: 'open',
            ),
            SessionView(
              id: 'session-3',
              title: 'Buổi 3: Hạ thân',
              scheduledDate: '2026-10-16',
              scheduledTime: '07:00',
              durationMin: 30,
              status: 'open',
            ),
          ],
        );

        final fakeStreakRepo = FakeStreakRepository(
          initialStreak: const StreakView(
            currentWeeks: 2,
            bestWeeks: 4,
            freezesAvailable: 1,
            thisWeek: StreakWeek(
              weekStart: '2026-10-12',
              targetSessions: 3,
              completedSessions: 0,
              status: 'in_progress',
            ),
          ),
        );

        final fakeUserRepo = FakeUserRepository(meResponse: demoMe);
        final fakePlanRepo = FakePlanRepository(planView: demoPlan);
        final fakeAuthRepo = FakeAuthRepository(initialUser: testUser);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
            planRepositoryProvider.overrideWithValue(fakePlanRepo),
            streakRepositoryProvider.overrideWithValue(fakeStreakRepo),
            buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
            coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
            nutritionRepositoryProvider.overrideWithValue(FakeNutritionRepository()),
          ],
        );
        addTearDown(container.dispose);

        final router = createAppRouter(initialLocation: '/home');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Ban đầu chưa có buổi hoàn thành: "0/3 buổi"
        expect(find.byKey(const ValueKey('home-week-sessions')), findsOneWidget);
        expect(find.text('0/3 buổi'), findsOneWidget);

        // Giả lập lưu buổi tập: cập nhật plan + streak repo và invalidate
        fakePlanRepo.planView = planWith1Done;
        fakeStreakRepo.streakView = const StreakView(
          currentWeeks: 2,
          bestWeeks: 4,
          freezesAvailable: 1,
          thisWeek: StreakWeek(
            weekStart: '2026-10-12',
            targetSessions: 3,
            completedSessions: 1,
            status: 'in_progress',
          ),
        );
        container.invalidate(homePlanProvider);
        container.invalidate(streakFutureProvider);
        await tester.pumpAndSettle();

        // Màn chính cập nhật số buổi mới ngay: "1/3 buổi"
        expect(find.text('1/3 buổi'), findsOneWidget);
      },
    );

    testWidgets(
      'Mở app có FastCache hiện dữ liệu ngay lập tức không bị chờ mạng',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Lưu trước bản cache vào FastCache
        await FastCache.saveMe(testUid, demoMe);
        await FastCache.savePlan(testUid, demoPlan);

        final fakeAuthRepo = FakeAuthRepository(initialUser: testUser);
        final fakeUserRepo = FakeUserRepository(meResponse: demoMe);
        final fakePlanRepo = FakePlanRepository(planView: demoPlan);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
            planRepositoryProvider.overrideWithValue(fakePlanRepo),
            streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
            buddyRepositoryProvider.overrideWithValue(FakeBuddyRepository()),
            coachRepositoryProvider.overrideWithValue(FakeCoachRepository()),
            nutritionRepositoryProvider.overrideWithValue(FakeNutritionRepository()),
          ],
        );
        addTearDown(container.dispose);

        // Mở app từ bootstrap '/'
        final router = createAppRouter(initialLocation: '/');

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: AppTheme.lightTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Đã vào ngay HomeScreen và hiển thị tên từ cache
        expect(find.textContaining('Nguyễn Văn Nhanh'), findsOneWidget);
      },
    );

    test(
      'Đăng xuất xoá toàn bộ FastCache (SharedPreferences)',
      () async {
        // Lưu trước dữ liệu vào FastCache
        await FastCache.saveMe(testUid, demoMe);
        await FastCache.savePlan(testUid, demoPlan);

        expect(await FastCache.getMe(testUid), isNotNull);
        expect(await FastCache.getPlan(testUid), isNotNull);

        final fakeAuthRepo = FakeAuthRepository(initialUser: testUser);

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            userRepositoryProvider.overrideWithValue(FakeUserRepository(meResponse: demoMe)),
          ],
        );
        addTearDown(container.dispose);

        // Thực hiện đăng xuất
        await appSignOutContainer(container);

        // FastCache đã bị xoá hoàn toàn
        expect(await FastCache.getMe(testUid), isNull);
        expect(await FastCache.getPlan(testUid), isNull);
      },
    );
  });
}
