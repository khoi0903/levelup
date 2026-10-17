import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/features/activity/data/repositories/api_activity_repository.dart';
import 'package:fitness_app/features/activity/data/repositories/fake_activity_repository.dart';
import 'package:fitness_app/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:fitness_app/features/auth/domain/models/auth_user.dart';
import 'package:fitness_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitness_app/features/health_connect/data/services/health_connect_service.dart';
import 'package:fitness_app/features/health_connect/domain/models/health_connect_state.dart';
import 'package:fitness_app/features/health_connect/presentation/controllers/health_connect_controller.dart';
import 'package:fitness_app/features/nutrition/data/photo/meal_photo.dart';
import 'package:fitness_app/features/nutrition/data/repositories/fake_nutrition_repository.dart';
import 'package:fitness_app/features/nutrition/domain/models/nutrition_models.dart';
import 'package:fitness_app/features/nutrition/presentation/controllers/nutrition_controller.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_plan_repository.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart'
    hide NutritionTarget;
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:fitness_app/features/workout/data/repositories/fake_workout_repository.dart';
import 'package:fitness_app/features/workout/domain/models/exercise_response.dart';
import 'package:fitness_app/features/workout/domain/models/extra_workout_builder.dart';
import 'package:fitness_app/features/workout/domain/models/workout_session_state.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeHealthConnectService extends HealthConnectService {
  bool available = true;
  bool permitted = true;
  int steps = 0;
  double calories = 0.0;

  @override
  Future<bool> isHealthConnectAvailable() async => available;

  @override
  Future<bool> hasPermissions() async => permitted;

  @override
  Future<bool> requestPermissions() async => permitted;

  @override
  Future<int> getTodaySteps() async => steps;

  @override
  Future<double> getTodayCaloriesBurned() async => calories;
}

class FakePhotoPicker implements MealPhotoPicker {
  @override
  Future<MealPhoto?> pick(MealPhotoSource source) async => null;
}

final testRefProvider = Provider<Ref>((ref) => ref);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final exCardio = const ExerciseResponse(
    id: 'ex-cardio-1',
    slug: 'jumping-jacks',
    nameVi: 'Jumping Jacks',
    primaryMuscle: 'cardio',
    difficulty: 2,
    tracking: 'duration',
  );

  final exChest = const ExerciseResponse(
    id: 'ex-chest-1',
    slug: 'push-up',
    nameVi: 'Hít đất',
    primaryMuscle: 'chest',
    difficulty: 3,
    tracking: 'reps',
  );

  final exLegs = const ExerciseResponse(
    id: 'ex-legs-1',
    slug: 'squat',
    nameVi: 'Squat',
    primaryMuscle: 'legs',
    difficulty: 2,
    tracking: 'reps',
  );

  final exCore = const ExerciseResponse(
    id: 'ex-core-1',
    slug: 'plank',
    nameVi: 'Plank',
    primaryMuscle: 'core',
    difficulty: 2,
    tracking: 'duration',
  );

  final exMobility1 = const ExerciseResponse(
    id: 'ex-mob-1',
    slug: 'cat-cow',
    nameVi: 'Giãn cơ Mèo - Bò',
    primaryMuscle: 'mobility',
    difficulty: 1,
    tracking: 'duration',
  );

  final exMobility2 = const ExerciseResponse(
    id: 'ex-mob-2',
    slug: 'child-pose',
    nameVi: 'Tư thế Em bé',
    primaryMuscle: 'mobility',
    difficulty: 1,
    tracking: 'duration',
  );

  final exMobility3 = const ExerciseResponse(
    id: 'ex-mob-3',
    slug: 'cobra-stretch',
    nameVi: 'Giãn cơ Rắn hổ mang',
    primaryMuscle: 'mobility',
    difficulty: 2,
    tracking: 'duration',
  );

  final allExercisesWithMobility = [
    exCardio,
    exChest,
    exLegs,
    exCore,
    exMobility1,
    exMobility2,
    exMobility3,
  ];

  group('Health Connect → Server Activity Sync', () {
    test('Gửi activity đúng body lên server khi đã cấp quyền', () async {
      final fakeService = FakeHealthConnectService()
        ..steps = 5200
        ..calories = 180.0;
      final fakeActivityRepo = FakeActivityRepository();

      var mockTime = DateTime(2026, 10, 17, 10, 0);

      final container = ProviderContainer(
        overrides: [
          healthConnectServiceProvider.overrideWithValue(fakeService),
          activityRepositoryProvider.overrideWithValue(fakeActivityRepo),
          userStatusFutureProvider.overrideWith((ref) async => const MeResponse(
                id: 'user-1',
                displayName: 'Test User',
                localDate: '2026-10-17',
              )),
        ],
      );
      addTearDown(container.dispose);

      HealthConnectController(
        fakeService,
        ref: container.read(testRefProvider),
        activityRepository: fakeActivityRepo,
        clock: () => mockTime,
        isPlatformSupportedOverride: () => true,
      );

      // Chờ checkStatus và refresh ban đầu
      await pumpEventQueue();

      expect(fakeActivityRepo.sentRequests.length, 1);
      final req = fakeActivityRepo.sentRequests.first;
      expect(req.localDate, '2026-10-17');
      expect(req.steps, 5200);
      expect(req.activeKcal, 180);
    });

    test('localDate dùng ngày điện thoại nếu server date lệch ngày', () async {
      final fakeService = FakeHealthConnectService()
        ..steps = 3000
        ..calories = 120.0;
      final fakeActivityRepo = FakeActivityRepository();

      final mockTime = DateTime(2026, 10, 17, 10, 0); // Ngày điện thoại: 2026-10-17

      final container = ProviderContainer(
        overrides: [
          healthConnectServiceProvider.overrideWithValue(fakeService),
          activityRepositoryProvider.overrideWithValue(fakeActivityRepo),
          // Server date lệch: 2026-10-16
          userStatusFutureProvider.overrideWith((ref) async => const MeResponse(
                id: 'user-1',
                displayName: 'Test User',
                localDate: '2026-10-16',
              )),
        ],
      );
      addTearDown(container.dispose);

      HealthConnectController(
        fakeService,
        ref: container.read(testRefProvider),
        activityRepository: fakeActivityRepo,
        clock: () => mockTime,
        isPlatformSupportedOverride: () => true,
      );

      await pumpEventQueue();

      expect(fakeActivityRepo.sentRequests.length, 1);
      expect(fakeActivityRepo.sentRequests.first.localDate, '2026-10-17');
    });

    test('Không gửi lại khi số liệu không tăng hoặc chưa đủ 15 phút', () async {
      final fakeService = FakeHealthConnectService()
        ..steps = 5000
        ..calories = 150.0;
      final fakeActivityRepo = FakeActivityRepository();

      var currentTime = DateTime(2026, 10, 17, 10, 0);

      final container = ProviderContainer(
        overrides: [
          healthConnectServiceProvider.overrideWithValue(fakeService),
          activityRepositoryProvider.overrideWithValue(fakeActivityRepo),
          userStatusFutureProvider.overrideWith((ref) async => const MeResponse(
                id: 'user-1',
                displayName: 'Test User',
                localDate: '2026-10-17',
              )),
        ],
      );
      addTearDown(container.dispose);

      final controller = HealthConnectController(
        fakeService,
        ref: container.read(testRefProvider),
        activityRepository: fakeActivityRepo,
        clock: () => currentTime,
        isPlatformSupportedOverride: () => true,
      );

      await pumpEventQueue();
      expect(fakeActivityRepo.sentRequests.length, 1);

      // Thử refresh sau 20 phút nhưng số liệu không tăng (vẫn 5000, 150)
      currentTime = currentTime.add(const Duration(minutes: 20));
      await controller.refreshTodayData();
      await pumpEventQueue();
      expect(fakeActivityRepo.sentRequests.length, 1);

      // Số liệu tăng nhưng chưa quá 15 phút (chỉ mới 5 phút trôi qua)
      currentTime = DateTime(2026, 10, 17, 10, 5);
      fakeService.steps = 6000;
      fakeService.calories = 180.0;
      await controller.refreshTodayData();
      await pumpEventQueue();
      expect(fakeActivityRepo.sentRequests.length, 1);

      // Đã qua 20 phút VÀ số liệu tăng → Gửi lần 2
      currentTime = DateTime(2026, 10, 17, 10, 25);
      await controller.refreshTodayData();
      await pumpEventQueue();
      expect(fakeActivityRepo.sentRequests.length, 2);
      expect(fakeActivityRepo.sentRequests.last.steps, 6000);
      expect(fakeActivityRepo.sentRequests.last.activeKcal, 180);
    });

    test('Lỗi mạng: bỏ qua im lặng không quăng ngoại lệ', () async {
      final fakeService = FakeHealthConnectService()
        ..steps = 4000
        ..calories = 100.0;
      final fakeActivityRepo = FakeActivityRepository()
        ..errorToThrow = Exception('Network error 500');

      final container = ProviderContainer(
        overrides: [
          healthConnectServiceProvider.overrideWithValue(fakeService),
          activityRepositoryProvider.overrideWithValue(fakeActivityRepo),
          userStatusFutureProvider.overrideWith((ref) async => const MeResponse(
                id: 'user-1',
                displayName: 'Test User',
                localDate: '2026-10-17',
              )),
        ],
      );
      addTearDown(container.dispose);

      final controller = HealthConnectController(
        fakeService,
        ref: container.read(testRefProvider),
        activityRepository: fakeActivityRepo,
        clock: () => DateTime(2026, 10, 17, 10, 0),
        isPlatformSupportedOverride: () => true,
      );

      // Chờ mà không ném lỗi ra ngoài
      await pumpEventQueue();
      expect(controller.state.status, HealthConnectStatus.authorized);
    });

    test('Không gửi khi chưa cấp quyền / web / iOS', () async {
      final fakeService = FakeHealthConnectService()
        ..permitted = false
        ..steps = 5000;
      final fakeActivityRepo = FakeActivityRepository();

      final container = ProviderContainer(
        overrides: [
          healthConnectServiceProvider.overrideWithValue(fakeService),
          activityRepositoryProvider.overrideWithValue(fakeActivityRepo),
        ],
      );
      addTearDown(container.dispose);

      HealthConnectController(
        fakeService,
        ref: container.read(testRefProvider),
        activityRepository: fakeActivityRepo,
        clock: () => DateTime(2026, 10, 17, 10, 0),
        isPlatformSupportedOverride: () => false, // Giả lập web/iOS
      );

      await pumpEventQueue();
      expect(fakeActivityRepo.sentRequests.isEmpty, isTrue);
    });
  });

  group('Màn Dinh dưỡng (NutritionScreen)', () {
    testWidgets('Hiện totalBurnedKcal và số bước khi steps > 0 kèm chú thích nhỏ',
        (tester) async {
      final nutritionRepo = FakeNutritionRepository(
        initial: const NutritionToday(
          localDate: '2026-10-17',
          target: NutritionTarget(
            macros: Macros(kcal: 2000, proteinG: 120, carbsG: 220, fatG: 60),
            waterMl: 2000,
          ),
          consumed: Macros(kcal: 1400, proteinG: 90, carbsG: 150, fatG: 45),
          burnedKcal: 200,
          activeKcal: 350,
          totalBurnedKcal: 350,
          steps: 5200,
        ),
      );

      final router = createAppRouter(initialLocation: '/nutrition');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(
                initialUser: const AuthUser(id: 'u1', email: 'u1@test.com'),
              ),
            ),
            nutritionRepositoryProvider.overrideWithValue(nutritionRepo),
            mealPhotoPickerProvider.overrideWithValue(FakePhotoPicker()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      // Hiển thị "Calo vận động: 350 kcal · 5200 bước"
      expect(find.byKey(const ValueKey('nutrition-burned-kcal')), findsOneWidget);
      expect(
        find.text('Calo vận động: 350 kcal · 5200 bước'),
        findsOneWidget,
      );

      // Hiển thị chú thích nhỏ
      expect(
        find.text('Calo vận động chỉ để tham khảo, mục tiêu ăn giữ nguyên'),
        findsOneWidget,
      );
    });

    testWidgets('Ẩn dòng calo đốt khi totalBurnedKcal == 0', (tester) async {
      final nutritionRepoZero = FakeNutritionRepository(
        initial: const NutritionToday(
          localDate: '2026-10-17',
          totalBurnedKcal: 0,
          steps: 0,
        ),
      );

      final router = createAppRouter(initialLocation: '/nutrition');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(
                initialUser: const AuthUser(id: 'u1', email: 'u1@test.com'),
              ),
            ),
            nutritionRepositoryProvider.overrideWithValue(nutritionRepoZero),
            mealPhotoPickerProvider.overrideWithValue(FakePhotoPicker()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('nutrition-burned-kcal')), findsNothing);
    });
  });

  group('Bài giãn cơ (primaryMuscle == mobility)', () {
    test('Các gợi ý thường KHÔNG chứa bài mobility', () {
      final quick5Items = buildSuggestedExercises(
        exercises: allExercisesWithMobility,
        type: SuggestedWorkoutType.quick5,
      );
      final fullBodyItems = buildSuggestedExercises(
        exercises: allExercisesWithMobility,
        type: SuggestedWorkoutType.fullBody,
      );
      final legsItems = buildSuggestedExercises(
        exercises: allExercisesWithMobility,
        type: SuggestedWorkoutType.legsGlutes,
      );
      final armsItems = buildSuggestedExercises(
        exercises: allExercisesWithMobility,
        type: SuggestedWorkoutType.armsShoulders,
      );
      final coreItems = buildSuggestedExercises(
        exercises: allExercisesWithMobility,
        type: SuggestedWorkoutType.coreAbs,
      );

      for (final items in [quick5Items, fullBodyItems, legsItems, armsItems, coreItems]) {
        for (final item in items) {
          expect(
            item.exercise?.primaryMuscle,
            isNot('mobility'),
            reason: 'Gợi ý thường không được chứa bài mobility: ${item.nameVi}',
          );
        }
      }
    });

    test('Có ≥ 3 bài mobility thì light10 đổi tên thành Giãn cơ 10 phút, 1 hiệp 30–45s, nghỉ 10s', () {
      final setup = buildSuggestedWorkoutSetup(
        exercises: allExercisesWithMobility,
        type: SuggestedWorkoutType.light10,
      );

      expect(setup.session.title, 'Giãn cơ 10 phút');
      expect(setup.items.length, greaterThanOrEqualTo(3));

      for (final item in setup.items) {
        expect(item.exercise?.primaryMuscle, 'mobility');
        expect(item.sets, 2);
        expect(item.reps, isNull);
        expect(item.durationSec, 45);
        expect(item.restSec, 10);
      }
    });

    test('Có < 3 bài mobility thì giữ Bản nhẹ 10 phút như cũ', () {
      final setup = buildSuggestedWorkoutSetup(
        exercises: [exCardio, exChest, exLegs, exMobility1, exMobility2], // chỉ có 2 bài mobility
        type: SuggestedWorkoutType.light10,
      );

      expect(setup.session.title, 'Bản nhẹ 10 phút');
      for (final item in setup.items) {
        expect(item.sets, 2);
        expect(item.restSec, 30);
      }
    });

    testWidgets('Màn tập: bài mobility tracking duration chạy đồng hồ, không mở camera',
        (tester) async {
      final setup = WorkoutSetup(
        session: const SessionView(
          id: 'test-mobility-session',
          title: 'Giãn cơ 10 phút',
          scheduledDate: '2026-10-17',
          scheduledTime: '',
          durationMin: 10,
          items: [
            ItemView(
              exerciseId: 'ex-mob-1',
              nameVi: 'Giãn cơ Mèo - Bò',
              sets: 1,
              durationSec: 30,
              restSec: 10,
            ),
          ],
        ),
        items: [
          WorkoutPlanItem(
            exerciseId: 'ex-mob-1',
            nameVi: 'Giãn cơ Mèo - Bò',
            sets: 1,
            durationSec: 30,
            restSec: 10,
            exercise: exMobility1,
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              initialUser: const AuthUser(id: 'u1', email: 'u1@test.com'),
            ),
          ),
          workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
        ],
      );
      addTearDown(container.dispose);

      container.read(activeWorkoutProvider.notifier).start(setup);

      final router = createAppRouter(initialLocation: '/workout/active');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      // Kiểm tra tên bài tập hiện đúng
      expect(find.text('Giãn cơ Mèo - Bò'), findsOneWidget);

      // Bài mobility: hiển thị mục tiêu 30 giây
      expect(find.text('Hiệp 1/1 · Mục tiêu 30 giây'), findsOneWidget);

      // Không hiển thị nút "Đếm bằng camera"
      expect(find.text('Đếm bằng camera'), findsNothing);

      // Hiển thị nút "Xong hiệp" (đếm tay)
      expect(find.text('Xong hiệp'), findsOneWidget);
    });

    testWidgets('Màn Tập thêm: tab Tự chọn có chip "Giãn cơ" để xem riêng',
        (tester) async {
      final router = createAppRouter(initialLocation: '/workout/extra');

      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(
                initialUser: const AuthUser(id: 'u1', email: 'u1@test.com'),
              ),
            ),
            workoutRepositoryProvider.overrideWithValue(
              FakeWorkoutRepository(exercises: allExercisesWithMobility),
            ),
            planRepositoryProvider.overrideWithValue(FakePlanRepository()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      // Trên màn Gợi ý: có card "Giãn cơ 10 phút" vì có >= 3 bài mobility
      expect(find.text('Giãn cơ 10 phút'), findsWidgets);

      // Chuyển sang tab "Tự chọn bài"
      await tester.tap(find.text('Tự chọn bài'));
      await tester.pumpAndSettle();

      // Mặc định (Tất cả): bài mobility KHÔNG hiện
      expect(find.text('Giãn cơ Mèo - Bò'), findsNothing);
      expect(find.text('Hít đất'), findsOneWidget);

      // Có chip "Giãn cơ"
      final mobilityChip = find.widgetWithText(FilterChip, 'Giãn cơ');
      expect(mobilityChip, findsOneWidget);

      // Bấm chip "Giãn cơ"
      await tester.tap(mobilityChip);
      await tester.pumpAndSettle();

      // Giờ bài mobility đã xuất hiện, bài bình thường bị ẩn
      expect(find.text('Giãn cơ Mèo - Bò'), findsOneWidget);
      expect(find.text('Hít đất'), findsNothing);
    });
  });
}
