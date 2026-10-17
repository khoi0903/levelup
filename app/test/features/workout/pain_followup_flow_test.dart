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
import 'package:fitness_app/features/workout/data/repositories/fake_workout_repository.dart';
import 'package:fitness_app/features/workout/domain/models/exercise_response.dart';
import 'package:fitness_app/features/workout/domain/models/workout_models.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test_helpers.dart';

FakeAuthRepository _signedInAuth() => FakeAuthRepository(
      initialUser: const AuthUser(id: 'u-1', email: 'test@levelup.vn'),
    );

const _squatItem = ItemView(
  exerciseId: squatId,
  nameVi: 'Squat',
  sets: 1,
  reps: 10,
);

void main() {
  group('1. Màn hình kết thúc: chọn vùng đau và loại đau', () {
    testWidgets(
      'Chọn vùng đau mà không chọn loại đau -> báo lỗi SnackBar, không gửi request',
      (tester) async {
        final h = WorkoutHarness(plan: planWith(const [_squatItem]));
        await h.pump(tester, '/workout/$sessionId');

        await tester.tap(find.text('Bắt đầu'));
        await tester.pumpAndSettle();

        h.clock.now = h.clock.now.add(const Duration(minutes: 6));
        await tester.tap(find.text('Xong hiệp'));
        await tester.pumpAndSettle();

        expect(find.text('Buổi tập vừa rồi như thế nào?'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('rpe-7')));
        await tester.pumpAndSettle();

        // Chọn vùng đau: Gối
        await tester.tap(find.text('Gối'));
        await tester.pumpAndSettle();

        // Thấy 2 chip loại đau xuất hiện
        expect(find.text('Mỏi cơ bình thường'), findsOneWidget);
        expect(find.text('Đau nhói / đau khớp'), findsOneWidget);

        // Bấm Xem kết quả mà CHƯA chọn loại đau
        await tester.tap(find.text('Xem kết quả'));
        await tester.pumpAndSettle();

        // Kiểm tra SnackBar nhắc nhở
        expect(
          find.text('Vui lòng chọn loại đau: mỏi cơ hay đau nhói / đau khớp.'),
          findsOneWidget,
        );
        // Chưa gửi request
        expect(h.repo.sentRequests, isEmpty);
      },
    );

    testWidgets(
      'Chọn "Mỏi cơ bình thường" -> hiện gợi ý mỏi cơ và request có painType = soreness',
      (tester) async {
        final h = WorkoutHarness(plan: planWith(const [_squatItem]));
        await h.pump(tester, '/workout/$sessionId');

        await tester.tap(find.text('Bắt đầu'));
        await tester.pumpAndSettle();

        h.clock.now = h.clock.now.add(const Duration(minutes: 6));
        await tester.tap(find.text('Xong hiệp'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('rpe-7')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Gối'));
        await tester.pumpAndSettle();

        // Chọn "Mỏi cơ bình thường"
        await tester.tap(find.text('Mỏi cơ bình thường'));
        await tester.pumpAndSettle();

        expect(
          find.text('Mỏi sau tập là bình thường. Giãn cơ, uống đủ nước nhé.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Xem kết quả'));
        await tester.pumpAndSettle();

        expect(h.repo.sentRequests.length, 1);
        final req = h.repo.sentRequests.first;
        expect(req.painAreas, [PainArea.knee]);
        expect(req.painType, 'soreness');
        final json = req.toJson();
        expect(json['painAreas'], ['knee']);
        expect(json['painType'], 'soreness');
      },
    );

    testWidgets(
      'Chọn "Đau nhói / đau khớp" -> hiện gợi ý đau nhói và request có painType = sharp',
      (tester) async {
        final h = WorkoutHarness(plan: planWith(const [_squatItem]));
        await h.pump(tester, '/workout/$sessionId');

        await tester.tap(find.text('Bắt đầu'));
        await tester.pumpAndSettle();

        h.clock.now = h.clock.now.add(const Duration(minutes: 6));
        await tester.tap(find.text('Xong hiệp'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('rpe-7')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Lưng dưới'));
        await tester.pumpAndSettle();

        // Chọn "Đau nhói / đau khớp"
        await tester.tap(find.text('Đau nhói / đau khớp'));
        await tester.pumpAndSettle();

        expect(
          find.text('Coach sẽ đổi bài tránh vùng này và hỏi thăm bạn ngày mai. Đau kéo dài thì nên đi khám.'),
          findsOneWidget,
        );

        await tester.tap(find.text('Xem kết quả'));
        await tester.pumpAndSettle();

        expect(h.repo.sentRequests.length, 1);
        final req = h.repo.sentRequests.first;
        expect(req.painAreas, [PainArea.lowerBack]);
        expect(req.painType, 'sharp');
        final json = req.toJson();
        expect(json['painAreas'], ['lower_back']);
        expect(json['painType'], 'sharp');
      },
    );

    testWidgets(
      'Không chọn vùng đau -> không hiện chip chọn loại đau, request không có painType',
      (tester) async {
        final h = WorkoutHarness(plan: planWith(const [_squatItem]));
        await h.pump(tester, '/workout/$sessionId');

        await tester.tap(find.text('Bắt đầu'));
        await tester.pumpAndSettle();

        h.clock.now = h.clock.now.add(const Duration(minutes: 6));
        await tester.tap(find.text('Xong hiệp'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('rpe-7')));
        await tester.pumpAndSettle();

        expect(find.text('Mỏi cơ bình thường'), findsNothing);
        expect(find.text('Đau nhói / đau khớp'), findsNothing);

        await tester.tap(find.text('Xem kết quả'));
        await tester.pumpAndSettle();

        expect(h.repo.sentRequests.length, 1);
        final req = h.repo.sentRequests.first;
        expect(req.painAreas, isEmpty);
        expect(req.painType, isNull);
        final json = req.toJson();
        expect(json.containsKey('painType'), isFalse);
        expect(json.containsKey('painAreas'), isFalse);
      },
    );
  });

  group('2. Màn hình Trang chủ: Thẻ hỏi thăm vùng đau', () {
    testWidgets(
      'Thẻ hỏi thăm xuất hiện khi painFollowUps có dữ liệu, bấm "Vẫn đau" gọi POST /pain-followups/knee body answer=same',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeUserRepo = FakeUserRepository(
          meResponse: const MeResponse(
            id: 'u-1',
            displayName: 'Khoi',
            localDate: '2026-10-17',
            painFollowUps: [
              PainFollowUp(bodyArea: 'knee', label: 'đầu gối', reportedOn: '2026-10-16', days: 1),
            ],
          ),
        );

        final router = createAppRouter(initialLocation: '/home');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(_signedInAuth()),
              userRepositoryProvider.overrideWithValue(fakeUserRepo),
              planRepositoryProvider.overrideWithValue(FakePlanRepository()),
              streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
              workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Kiểm tra thẻ hỏi thăm
        expect(find.byKey(const ValueKey('pain-followup-card-knee')), findsOneWidget);
        expect(find.text('Đầu gối hôm nay sao rồi?'), findsOneWidget);
        expect(find.text('Báo đau 1 ngày trước'), findsOneWidget);

        // Bấm "Vẫn đau"
        final sameBtn = find.byKey(const ValueKey('pain-btn-same-knee'));
        expect(sameBtn, findsOneWidget);
        await tester.tap(sameBtn);
        await tester.pumpAndSettle();

        // Kiểm tra đã gọi answerPainFollowUp với knee và same
        expect(fakeUserRepo.answeredPainFollowUps.length, 1);
        expect(fakeUserRepo.answeredPainFollowUps.first, (bodyArea: 'knee', answer: 'same'));
      },
    );

    testWidgets(
      'Backend trả 404 cho POST /pain-followups/{area} -> thẻ biến mất và refresh /me',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeUserRepo = FakeUserRepository(
          meResponse: const MeResponse(
            id: 'u-1',
            displayName: 'Khoi',
            localDate: '2026-10-17',
            painFollowUps: [
              PainFollowUp(bodyArea: 'knee', label: 'đầu gối', reportedOn: '2026-10-15', days: 2),
            ],
          ),
        );
        fakeUserRepo.painFollowUpErrorToThrow = const ApiException(
          statusCode: 404,
          code: 'PAIN_FOLLOWUP_NOT_FOUND',
        );

        final router = createAppRouter(initialLocation: '/home');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(_signedInAuth()),
              userRepositoryProvider.overrideWithValue(fakeUserRepo),
              planRepositoryProvider.overrideWithValue(FakePlanRepository()),
              streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
              workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('pain-followup-card-knee')), findsOneWidget);

        // Bấm nút bất kỳ (ví dụ Hết đau)
        await tester.tap(find.byKey(const ValueKey('pain-btn-gone-knee')));
        await tester.pumpAndSettle();

        // Thẻ biến mất vì 404
        expect(find.byKey(const ValueKey('pain-followup-card-knee')), findsNothing);
      },
    );

    testWidgets(
      'Phản hồi status == injury -> hiện cảnh báo giữ nguyên cho tới khi bấm "Đã hiểu"',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeUserRepo = FakeUserRepository(
          meResponse: const MeResponse(
            id: 'u-1',
            displayName: 'Khoi',
            localDate: '2026-10-17',
            painFollowUps: [
              PainFollowUp(bodyArea: 'knee', label: 'đầu gối', reportedOn: '2026-10-14', days: 3),
            ],
          ),
        );
        fakeUserRepo.painFollowUpResponseToReturn = const PainFollowUpResponse(
          status: 'injury',
          message: 'Bạn đau đầu gối đã 3 ngày liên tiếp. Hãy nghỉ ngơi và đi khám nếu cần.',
        );

        final router = createAppRouter(initialLocation: '/home');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(_signedInAuth()),
              userRepositoryProvider.overrideWithValue(fakeUserRepo),
              planRepositoryProvider.overrideWithValue(FakePlanRepository()),
              streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
              workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Bấm Đau hơn
        await tester.tap(find.byKey(const ValueKey('pain-btn-worse-knee')));
        await tester.pumpAndSettle();

        // Thẻ cảnh báo chấn thương xuất hiện
        expect(find.text('Đầu gối cần chú ý'), findsOneWidget);
        expect(
          find.text('Bạn đau đầu gối đã 3 ngày liên tiếp. Hãy nghỉ ngơi và đi khám nếu cần.'),
          findsOneWidget,
        );

        // Chờ 5 giây xem thẻ có tự biến mất không (nó KHÔNG được tự biến mất)
        await tester.pump(const Duration(seconds: 5));
        expect(find.text('Đầu gối cần chú ý'), findsOneWidget);

        // Bấm "Đã hiểu"
        final dismissBtn = find.byKey(const ValueKey('pain-dismiss-injury-knee'));
        expect(dismissBtn, findsOneWidget);
        await tester.tap(dismissBtn);
        await tester.pumpAndSettle();

        // Thẻ đã biến mất
        expect(find.text('Đầu gối cần chú ý'), findsNothing);
      },
    );
  });

  group('3. Màn hình Tập thêm: Dòng nhắc nhở và 2 nút lựa chọn nhanh', () {
    testWidgets(
      'Người dùng có painFollowUps hoặc lastSavedWorkout sharp -> hiện dòng nhắc nhở và 2 nút',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        const exPushup = ExerciseResponse(
          id: '64b000000000000000000001',
          slug: 'push-up',
          nameVi: 'Hít đất',
          primaryMuscle: 'chest',
          difficulty: 2,
          tracking: 'reps',
        );

        final fakeUserRepo = FakeUserRepository(
          meResponse: const MeResponse(
            id: 'u-1',
            displayName: 'Khoi',
            localDate: '2026-10-17',
            painFollowUps: [
              PainFollowUp(bodyArea: 'knee', label: 'đầu gối', reportedOn: '2026-10-16', days: 1),
            ],
          ),
        );

        final router = createAppRouter(initialLocation: '/workout/extra');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(_signedInAuth()),
              userRepositoryProvider.overrideWithValue(fakeUserRepo),
              planRepositoryProvider.overrideWithValue(FakePlanRepository()),
              streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
              workoutRepositoryProvider.overrideWithValue(
                FakeWorkoutRepository(exercises: [exPushup]),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Kiểm tra dòng nhắc nhở
        expect(find.byKey(const ValueKey('pain-reminder-banner')), findsOneWidget);
        expect(
          find.text('Bạn đang đau đầu gối. Nghỉ cũng là một phần của tập luyện; nếu vẫn muốn tập, mình đã bỏ bài tác động vào vùng này.'),
          findsOneWidget,
        );

        // Kiểm tra 2 nút lựa chọn nhanh
        expect(find.byKey(const ValueKey('extra-pain-other-part-btn')), findsOneWidget);
        expect(find.byKey(const ValueKey('extra-pain-light10-btn')), findsOneWidget);

        // Bấm "Tập phần khác" chuyển sang tab Tự chọn bài
        await tester.tap(find.byKey(const ValueKey('extra-pain-other-part-btn')));
        await tester.pumpAndSettle();

        expect(find.text('Tìm bài tập (không dấu)...'), findsOneWidget);
      },
    );
  });

  group('4. Màn hình Hồ sơ: Mục "Vùng đang đau / chấn thương" và nút "Đã khỏi"', () {
    testWidgets(
      'Hồ sơ hiển thị activeInjuries, bấm "Đã khỏi" hỏi xác nhận và gọi answerPainFollowUp("gone")',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeUserRepo = FakeUserRepository(
          meResponse: const MeResponse(
            id: 'u-1',
            displayName: 'Khoi',
            localDate: '2026-10-17',
            activeInjuries: [
              ActiveInjury(bodyArea: 'knee', label: 'đầu gối'),
            ],
          ),
        );

        final router = createAppRouter(initialLocation: '/profile');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(_signedInAuth()),
              userRepositoryProvider.overrideWithValue(fakeUserRepo),
              planRepositoryProvider.overrideWithValue(FakePlanRepository()),
              streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
              workoutRepositoryProvider.overrideWithValue(FakeWorkoutRepository()),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pumpAndSettle();

        // Mục "Vùng đang đau / chấn thương"
        expect(find.text('Vùng đang đau / chấn thương'), findsOneWidget);
        expect(find.byKey(const ValueKey('injury-label-knee')), findsOneWidget);
        expect(find.text('Đầu gối'), findsOneWidget);

        final recoveredBtn = find.byKey(const ValueKey('injury-recovered-knee'));
        expect(recoveredBtn, findsOneWidget);

        // Bấm "Đã khỏi"
        await tester.tap(recoveredBtn);
        await tester.pumpAndSettle();

        // Hiện dialog xác nhận
        expect(find.text('Đã khỏi đầu gối?'), findsOneWidget);
        expect(
          find.text('Bạn đã khỏi đau vùng đầu gối và sẵn sàng tập lại bình thường?'),
          findsOneWidget,
        );

        // Bấm "Chưa" -> không gọi API
        await tester.tap(find.text('Chưa'));
        await tester.pumpAndSettle();
        expect(fakeUserRepo.answeredPainFollowUps, isEmpty);

        // Bấm lại "Đã khỏi"
        await tester.tap(recoveredBtn);
        await tester.pumpAndSettle();

        // Bấm nút "Đã khỏi" trong dialog
        await tester.tap(find.byKey(const ValueKey('injury-confirm-recovered-knee')));
        await tester.pumpAndSettle();

        // Gọi API thành công với gone
        expect(fakeUserRepo.answeredPainFollowUps.length, 1);
        expect(fakeUserRepo.answeredPainFollowUps.first, (bodyArea: 'knee', answer: 'gone'));
      },
    );
  });
}
