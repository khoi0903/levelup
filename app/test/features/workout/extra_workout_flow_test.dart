import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:fitness_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitness_app/features/nutrition/data/photo/meal_photo.dart';
import 'package:fitness_app/features/nutrition/data/repositories/fake_nutrition_repository.dart';
import 'package:fitness_app/features/nutrition/domain/models/nutrition_models.dart';
import 'package:fitness_app/features/nutrition/presentation/controllers/nutrition_controller.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_plan_repository.dart';
import 'package:fitness_app/features/auth/domain/models/auth_user.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart'
    hide NutritionTarget;
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/streak/data/repositories/fake_streak_repository.dart';
import 'package:fitness_app/features/streak/presentation/controllers/streak_controller.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:fitness_app/features/workout/data/repositories/fake_workout_repository.dart';
import 'package:fitness_app/features/workout/domain/models/exercise_response.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:fitness_app/features/workout/presentation/screens/workout_extra_screen.dart';
import 'package:fitness_app/features/workout/presentation/screens/workout_start_screen.dart';
import 'package:fitness_app/core/widgets/primary_button.dart';
import 'package:fitness_app/core/widgets/secondary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test_helpers.dart';

FakeAuthRepository signedInAuth() => FakeAuthRepository(
      initialUser: const AuthUser(id: 'test-user', email: 'test@levelup.vn'),
    );

class FakePhotoPicker implements MealPhotoPicker {
  @override
  Future<MealPhoto?> pick(MealPhotoSource source) async => null;
}

void main() {
  const exPushup = ExerciseResponse(
    id: '64b000000000000000000001',
    slug: 'push-up',
    nameVi: 'Hít đất',
    primaryMuscle: 'chest',
    difficulty: 3,
    tracking: 'reps',
  );

  const exSquat = ExerciseResponse(
    id: '64b000000000000000000002',
    slug: 'squat',
    nameVi: 'Squat',
    primaryMuscle: 'legs',
    difficulty: 3,
    tracking: 'reps',
  );

  const exPlank = ExerciseResponse(
    id: '64b000000000000000000003',
    slug: 'plank',
    nameVi: 'Plank',
    primaryMuscle: 'core',
    difficulty: 2,
    tracking: 'duration',
  );

  final testLibrary = [exPushup, exSquat, exPlank];

  group('ExtraWorkoutFlow - Luồng Tập thêm & Calo đốt', () {
    testWidgets(
      'Trang chủ: buổi hôm nay đã xong -> nút "Tập thêm" mở /workout/extra, không mở buổi ngày mai',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.now();
        final todayStr = localDateString(now);
        final tomorrow = now.add(const Duration(days: 1));
        final tomorrowStr = localDateString(tomorrow);

        final plan = PlanView(
          id: 'plan-1',
          weekStart: '2026-10-05',
          status: 'active',
          targetSessions: 3,
          sessions: [
            SessionView(
              id: 'sess-today-done',
              scheduledDate: todayStr,
              scheduledTime: '07:00',
              title: 'Buổi hôm nay',
              status: 'completed', // đã tập xong
              durationMin: 20,
              items: const [
                ItemView(exerciseId: '64b000000000000000000001', sets: 2, reps: 10),
              ],
            ),
            SessionView(
              id: 'sess-tomorrow',
              scheduledDate: tomorrowStr,
              scheduledTime: '07:00',
              title: 'Buổi ngày mai',
              status: 'planned',
              durationMin: 25,
              items: const [
                ItemView(exerciseId: '64b000000000000000000002', sets: 3, reps: 12),
              ],
            ),
          ],
        );

        final userRepo = FakeUserRepository(
          meResponse: MeResponse(
            id: 'u-1',
            displayName: 'Khoi',
            localDate: todayStr,
          ),
        );

        final workoutRepo = FakeWorkoutRepository(exercises: testLibrary);

        final router = createAppRouter(initialLocation: '/home');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(signedInAuth()),
              userRepositoryProvider.overrideWithValue(userRepo),
              planRepositoryProvider.overrideWithValue(
                FakePlanRepository(planView: plan),
              ),
              workoutRepositoryProvider.overrideWithValue(workoutRepo),
              streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Nút chính trên Home là "Tập thêm"
        final tapThemFinder = find.widgetWithText(PrimaryButton, 'Tập thêm');
        expect(tapThemFinder, findsOneWidget);

        // Bấm "Tập thêm"
        await tester.ensureVisible(tapThemFinder);
        await tester.tap(tapThemFinder);
        await tester.pumpAndSettle();

        // Mở ra màn "Tập thêm", KHÔNG mở "Buổi ngày mai"
        expect(find.text('Tập thêm'), findsWidgets);
        expect(find.text('Buổi gợi ý'), findsOneWidget);
        expect(find.text('Tự chọn bài'), findsOneWidget);
        expect(find.text('Tập lại buổi hôm nay'), findsOneWidget);
      },
    );

    testWidgets(
      'Màn /workout/extra: chọn buổi gợi ý -> Bắt đầu -> Kết thúc -> POST /workouts không có plannedSessionId',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.now();
        final todayStr = localDateString(now);

        final plan = PlanView(
          id: 'plan-1',
          weekStart: '2026-10-05',
          status: 'active',
          targetSessions: 3,
          sessions: [],
        );

        final workoutRepo = FakeWorkoutRepository(exercises: testLibrary);
        final clock = FakeClock();
        final router = createAppRouter(initialLocation: '/workout/extra');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(signedInAuth()),
              userRepositoryProvider.overrideWithValue(
                FakeUserRepository(
                  meResponse: MeResponse(id: 'u-1', displayName: 'Khoi', localDate: todayStr),
                ),
              ),
              planRepositoryProvider.overrideWithValue(
                FakePlanRepository(planView: plan),
              ),
              workoutRepositoryProvider.overrideWithValue(workoutRepo),
              repSessionFactoryProvider.overrideWithValue(NoCameraFactory()),
              workoutClockProvider.overrideWithValue(clock.call),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Thấy các thẻ gợi ý
        expect(find.text('5 phút nhanh'), findsOneWidget);
        expect(find.text('Toàn thân'), findsOneWidget);

        // Chọn "5 phút nhanh"
        await tester.tap(find.text('5 phút nhanh'));
        await tester.pumpAndSettle();

        // Vào màn tổng quan buổi tập
        expect(find.text('5 phút nhanh'), findsWidgets);
        expect(find.text('Bắt đầu'), findsOneWidget);

        // Bấm "Bắt đầu"
        await tester.tap(find.text('Bắt đầu'));
        await tester.pumpAndSettle();

        // Ở màn tập luyện active
        expect(find.textContaining('Mục tiêu'), findsWidgets);

        // Hoàn thành các hiệp để kết thúc buổi
        clock.now = clock.now.add(const Duration(minutes: 6));
        var guard = 0;
        while (find.text('Buổi tập vừa rồi như thế nào?').evaluate().isEmpty && guard < 40) {
          guard++;
          final skipRest = find.text('Bỏ qua nghỉ');
          if (skipRest.evaluate().isNotEmpty) {
            await tester.tap(skipRest.first);
            await tester.pump();
            continue;
          }
          final addTime = find.text('+5s');
          if (addTime.evaluate().isNotEmpty) {
            await tester.tap(addTime.first);
            await tester.pump();
          }
          final xongHiep = find.text('Xong hiệp');
          if (xongHiep.evaluate().isNotEmpty) {
            await tester.tap(xongHiep.first);
            await tester.pump();
          }
        }

        await tester.pumpAndSettle();

        // Màn RPE/kết thúc
        expect(find.text('Buổi tập vừa rồi như thế nào?'), findsOneWidget);
        await tester.tap(find.text('Xem kết quả'));
        await tester.pumpAndSettle();

        // Kiểm tra request đã gửi đi
        expect(workoutRepo.sentRequests, isNotEmpty);
        final sent = workoutRepo.sentRequests.last;
        // KHÔNG có plannedSessionId
        expect(sent.plannedSessionId, isNull);

        // Màn kết quả: có huy hiệu "Buổi tập thêm", calo đốt, nút "Tập thêm"
        expect(find.byKey(const ValueKey('result-extra-badge')), findsOneWidget);
        expect(find.text('Buổi tập thêm'), findsOneWidget);
        expect(find.byKey(const ValueKey('result-kcal-burned')), findsOneWidget);
        expect(find.text('ước tính'), findsOneWidget);
        expect(find.widgetWithText(SecondaryButton, 'Tập thêm'), findsOneWidget);
      },
    );

    testWidgets(
      'Màn /workout/extra: tự chọn bài tìm kiếm không dấu -> Bắt đầu -> POST /workouts không có plannedSessionId',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.now();
        final todayStr = localDateString(now);

        final plan = PlanView(
          id: 'plan-1',
          weekStart: '2026-10-05',
          status: 'active',
          targetSessions: 3,
          sessions: [],
        );

        final workoutRepo = FakeWorkoutRepository(exercises: testLibrary);
        final clock = FakeClock();
        final router = createAppRouter(initialLocation: '/workout/extra');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(signedInAuth()),
              userRepositoryProvider.overrideWithValue(
                FakeUserRepository(
                  meResponse: MeResponse(id: 'u-1', displayName: 'Khoi', localDate: todayStr),
                ),
              ),
              planRepositoryProvider.overrideWithValue(
                FakePlanRepository(planView: plan),
              ),
              workoutRepositoryProvider.overrideWithValue(workoutRepo),
              repSessionFactoryProvider.overrideWithValue(NoCameraFactory()),
              workoutClockProvider.overrideWithValue(clock.call),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Chuyển sang Tab "Tự chọn bài"
        await tester.tap(find.text('Tự chọn bài'));
        await tester.pumpAndSettle();

        // Tìm bài bằng tiếng Việt không dấu: "hit dat"
        await tester.enterText(find.byType(TextField), 'hit dat');
        await tester.pumpAndSettle();

        // Thấy bài "Hít đất"
        expect(find.text('Hít đất'), findsOneWidget);
        expect(find.text('Squat'), findsNothing);

        // Tích chọn bài "Hít đất"
        await tester.tap(find.text('Hít đất'));
        await tester.pumpAndSettle();

        // Nút ở đáy: "Bắt đầu (1 bài)"
        final startBtn = find.byKey(const ValueKey('start-custom-workout-button'));
        expect(startBtn, findsOneWidget);
        expect(find.text('Bắt đầu (1 bài)'), findsOneWidget);
        // Chọn bài không tải lại danh sách (trước đây màn hình nháy trắng mỗi lần chọn)
        expect(workoutRepo.getExercisesCalls, 1);
        await tester.tap(find.text('Hít đất'));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Hít đất'));
        await tester.pumpAndSettle();
        expect(workoutRepo.getExercisesCalls, 1);

        // Bấm Bắt đầu
        await tester.tap(startBtn);
        await tester.pumpAndSettle();

        // Vào màn tổng quan
        expect(find.text('Bắt đầu'), findsOneWidget);
        await tester.tap(find.text('Bắt đầu'));
        await tester.pumpAndSettle();

        // Hoàn thành buổi
        clock.now = clock.now.add(const Duration(minutes: 6));
        var guard = 0;
        while (find.text('Buổi tập vừa rồi như thế nào?').evaluate().isEmpty && guard < 40) {
          guard++;
          final skipRest = find.text('Bỏ qua nghỉ');
          if (skipRest.evaluate().isNotEmpty) {
            await tester.tap(skipRest.first);
            await tester.pump();
            continue;
          }
          final xongHiep = find.text('Xong hiệp');
          if (xongHiep.evaluate().isNotEmpty) {
            await tester.tap(xongHiep.first);
            await tester.pump();
          }
        }
        await tester.pumpAndSettle();

        expect(find.text('Buổi tập vừa rồi như thế nào?'), findsOneWidget);
        await tester.tap(find.text('Xem kết quả'));
        await tester.pumpAndSettle();

        // Request gửi lên không có plannedSessionId
        final sent = workoutRepo.sentRequests.last;
        expect(sent.plannedSessionId, isNull);
        expect(sent.sets.first.exerciseId, exPushup.id);
      },
    );

    testWidgets(
      'Màn Dinh dưỡng: hiện dòng "Đã đốt khi tập: X kcal" khi burnedKcal > 0',
      (tester) async {
        final nutritionRepoWithKcal = FakeNutritionRepository(
          initial: const NutritionToday(
            localDate: '2026-10-05',
            target: NutritionTarget(
              macros: Macros(kcal: 2000, proteinG: 120, carbsG: 220, fatG: 60),
              waterMl: 2000,
            ),
            consumed: Macros(kcal: 1400, proteinG: 90, carbsG: 150, fatG: 45),
            burnedKcal: 320,
          ),
        );

        final router = createAppRouter(initialLocation: '/nutrition');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(signedInAuth()),
              nutritionRepositoryProvider.overrideWithValue(nutritionRepoWithKcal),
              mealPhotoPickerProvider.overrideWithValue(FakePhotoPicker()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Hiển thị "Đã đốt khi tập: 320 kcal"
        expect(find.byKey(const ValueKey('nutrition-burned-kcal')), findsOneWidget);
        expect(find.text('Đã đốt khi tập: 320 kcal'), findsOneWidget);
      },
    );

    testWidgets(
      'Màn Dinh dưỡng: ẩn dòng calo đốt khi burnedKcal == 0',
      (tester) async {
        final nutritionRepoZeroKcal = FakeNutritionRepository(
          initial: const NutritionToday(
            localDate: '2026-10-05',
            target: NutritionTarget(
              macros: Macros(kcal: 2000, proteinG: 120, carbsG: 220, fatG: 60),
              waterMl: 2000,
            ),
            consumed: Macros(kcal: 1400, proteinG: 90, carbsG: 150, fatG: 45),
            burnedKcal: 0,
          ),
        );

        final router = createAppRouter(initialLocation: '/nutrition');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(signedInAuth()),
              nutritionRepositoryProvider.overrideWithValue(nutritionRepoZeroKcal),
              mealPhotoPickerProvider.overrideWithValue(FakePhotoPicker()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Ẩn khi burnedKcal == 0
        expect(find.byKey(const ValueKey('nutrition-burned-kcal')), findsNothing);
      },
    );

    testWidgets(
      'todayCheckin thấp → buổi gợi ý ít hiệp hơn + dòng gợi ý',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final userRepo = FakeUserRepository(
          meResponse: const MeResponse(
            id: 'u-low',
            displayName: 'Khoi',
            localDate: '2026-10-09',
            todayCheckin: TodayCheckin(energy: 'tired', sleep: 'lt6'),
          ),
        );

        final plan = PlanView(
          id: 'plan-1',
          weekStart: '2026-10-05',
          status: 'active',
          targetSessions: 3,
          sessions: const [],
        );

        final workoutRepo = FakeWorkoutRepository(exercises: testLibrary);
        final router = createAppRouter(initialLocation: '/workout/extra');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(signedInAuth()),
              userRepositoryProvider.overrideWithValue(userRepo),
              planRepositoryProvider.overrideWithValue(
                FakePlanRepository(planView: plan),
              ),
              workoutRepositoryProvider.overrideWithValue(workoutRepo),
              streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Dòng gợi ý trên đầu: "Sáng nay bạn thấy mệt nên buổi gợi ý nhẹ hơn"
        expect(
          find.text('Sáng nay bạn thấy mệt nên buổi gợi ý nhẹ hơn'),
          findsOneWidget,
        );

        // 2. Mức 5 phút được chọn sẵn mặc định (ngắn nhất)
        final chip5 = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, '5 phút'),
        );
        expect(chip5.selected, isTrue);

        // Mức 20 phút không cho phép (disabled) khi check-in thấp
        final chip20 = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, '20 phút'),
        );
        expect(chip20.onSelected, isNull);

        // 3. Buổi gợi ý ít hiệp hơn: bấm vào '5 phút nhanh'
        await tester.tap(find.text('5 phút nhanh'));
        await tester.pumpAndSettle();

        // Buổi tập mở ra với 1 hiệp mỗi bài (thay vì 2 hiệp khi bình thường)
        expect(find.byType(WorkoutStartScreen), findsOneWidget);
        expect(find.textContaining('1 hiệp'), findsWidgets);
      },
    );

    testWidgets(
      'tab Tập không có buổi hôm nay → vào màn Tập thêm',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const todayStr = '2026-10-09';
        const tomorrowStr = '2026-10-10';

        // Kế hoạch tuần này chỉ có buổi hôm nay đã bỏ (skipped) và buổi ngày mai
        final plan = PlanView(
          id: 'plan-1',
          weekStart: '2026-10-05',
          status: 'active',
          targetSessions: 3,
          sessions: const [
            SessionView(
              id: 'sess-today-skipped',
              scheduledDate: todayStr,
              scheduledTime: '07:00',
              title: 'Buổi hôm nay đã bỏ',
              status: 'skipped', // đã bỏ, không tính là mở
              durationMin: 20,
              items: [
                ItemView(exerciseId: '64b000000000000000000001', sets: 2, reps: 10),
              ],
            ),
            SessionView(
              id: 'sess-tomorrow',
              scheduledDate: tomorrowStr,
              scheduledTime: '07:00',
              title: 'Buổi ngày mai',
              status: 'planned',
              durationMin: 25,
              items: [
                ItemView(exerciseId: '64b000000000000000000002', sets: 3, reps: 12),
              ],
            ),
          ],
        );

        final userRepo = FakeUserRepository(
          meResponse: const MeResponse(
            id: 'u-1',
            displayName: 'Khoi',
            localDate: todayStr,
          ),
        );

        final workoutRepo = FakeWorkoutRepository(exercises: testLibrary);
        final router = createAppRouter(initialLocation: '/workout');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(signedInAuth()),
              userRepositoryProvider.overrideWithValue(userRepo),
              planRepositoryProvider.overrideWithValue(
                FakePlanRepository(planView: plan),
              ),
              workoutRepositoryProvider.overrideWithValue(workoutRepo),
              streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Mở thẳng màn Tập thêm
        expect(find.byType(WorkoutExtraScreen), findsOneWidget);
        expect(find.text('Tập thêm'), findsOneWidget);
      },
    );

    testWidgets(
      'Tự chọn bài: hiện bài cần tạ với nhãn và chọn được, bài chống chỉ định mờ và không chọn được',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // 3 bài tập:
        // 1. Hít đất (phù hợp)
        // 2. Lunge với tạ (cần tạ đơn)
        // 3. Squat (chống chỉ định chấn thương gối)
        const exPush = ExerciseResponse(
          id: 'ex-push',
          slug: 'push-up',
          nameVi: 'Hít đất',
          primaryMuscle: 'chest',
          difficulty: 3,
          tracking: 'reps',
          equipment: [],
          contraindications: [],
          isActive: true,
        );

        const exDumbbellLunge = ExerciseResponse(
          id: 'ex-lunge',
          slug: 'lunge',
          nameVi: 'Lunge với tạ',
          primaryMuscle: 'legs',
          difficulty: 3,
          tracking: 'reps',
          equipment: ['dumbbell'],
          contraindications: [],
          isActive: true,
        );

        const exKneeSquat = ExerciseResponse(
          id: 'ex-squat',
          slug: 'squat',
          nameVi: 'Squat',
          primaryMuscle: 'legs',
          difficulty: 3,
          tracking: 'reps',
          equipment: [],
          contraindications: ['knee'],
          isActive: true,
        );

        // User tập ở nhà, không có tạ đơn, đang bị đau gối
        final userRepo = FakeUserRepository(
          meResponse: const MeResponse(
            id: 'u-injury',
            displayName: 'Khoi',
            localDate: '2026-10-09',
            profile: UserProfile(
              location: 'home',
              equipment: [],
            ),
            injuries: [
              UserInjury(bodyArea: 'knee', active: true),
            ],
          ),
        );

        final plan = PlanView(
          id: 'plan-1',
          weekStart: '2026-10-05',
          status: 'active',
          targetSessions: 3,
          sessions: const [],
        );

        final workoutRepo = FakeWorkoutRepository(
          exercises: [exPush, exDumbbellLunge, exKneeSquat],
        );

        final router = createAppRouter(initialLocation: '/workout/extra');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(signedInAuth()),
              userRepositoryProvider.overrideWithValue(userRepo),
              planRepositoryProvider.overrideWithValue(
                FakePlanRepository(planView: plan),
              ),
              workoutRepositoryProvider.overrideWithValue(workoutRepo),
              streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Chuyển sang Tab 2: "Tự chọn bài"
        await tester.tap(find.text('Tự chọn bài'));
        await tester.pumpAndSettle();

        // 1. Bài cần tạ: hiện nhãn "Cần tạ đơn" và VẪN CHỌN ĐƯỢC
        expect(find.text('Lunge với tạ'), findsOneWidget);
        expect(find.text('Cần tạ đơn'), findsOneWidget);

        await tester.tap(find.text('Lunge với tạ'));
        await tester.pumpAndSettle();

        // Đã chọn được bài -> nút Bắt đầu đổi thành "Bắt đầu (1 bài)"
        expect(find.text('Bắt đầu (1 bài)'), findsOneWidget);

        // 2. Bài chống chỉ định: hiện mờ, nhãn "Không hợp với chấn thương gối", KHÔNG CHỌN ĐƯỢC
        expect(find.text('Squat'), findsOneWidget);
        expect(find.text('Không hợp với chấn thương gối'), findsOneWidget);

        await tester.tap(find.text('Squat'));
        await tester.pumpAndSettle();

        // Số bài chọn vẫn là 1 (không chọn được Squat)
        expect(find.text('Bắt đầu (1 bài)'), findsOneWidget);
      },
    );
  });
}
