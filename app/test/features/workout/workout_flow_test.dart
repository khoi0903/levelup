import 'package:fitness_app/features/workout/data/camera/camera_setup_skip.dart';
import 'package:fitness_app/features/workout/data/camera/camera_permission.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/workout/data/camera/rep_counting_session.dart';
import 'package:fitness_app/features/workout/data/repositories/fake_workout_repository.dart';
import 'package:fitness_app/features/workout/domain/models/workout_models.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test_helpers.dart';

const squatItem = ItemView(
  exerciseId: squatId,
  nameVi: 'Squat',
  sets: 1,
  reps: 10,
);
const plankItem = ItemView(
  exerciseId: plankId,
  nameVi: 'Plank',
  sets: 1,
  durationSec: 30,
);

const cameraSnapshot = RepSnapshot(
  repCount: 8,
  averageConfidence: 0.82,
  formScore: 75,
  issues: [FormIssueLog(repIndex: 3, code: 'shallow_depth', severity: 2)],
  status: RepCountingStatus.running,
);

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  group('Luồng tập đếm tay', () {
    testWidgets('Tổng quan → Đang tập → RPE → Kết quả, body đúng', (
      tester,
    ) async {
      final h = WorkoutHarness(plan: planWith(const [squatItem]));
      await h.pump(tester, '/workout/$sessionId');

      expect(find.text('Toàn thân'), findsOneWidget);
      expect(find.text('1 hiệp × 10 lần'), findsOneWidget);
      await tapText(tester, 'Bắt đầu');

      expect(find.text('Hiệp 1/1 · Mục tiêu 10 lần'), findsOneWidget);
      // Không có camera trên máy test: chỉ còn nút đếm tay.
      expect(find.text('Đếm bằng camera'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Tăng Số lần'));
      await tester.pump();
      expect(find.byKey(const ValueKey('manual-reps')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('manual-reps'))).data,
        '11',
      );
      h.clock.now = h.clock.now.add(const Duration(minutes: 2));
      await tapText(tester, 'Xong hiệp');

      expect(find.text('Buổi tập vừa rồi như thế nào?'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rpe-8')));
      await tester.pump();
      await tapText(tester, 'Gối');
      await tapText(tester, 'Xem kết quả');

      final body = h.repo.sentRequests.single.toJson();
      expect(body['plannedSessionId'], sessionId);
      expect(body['variant'], 'normal');
      expect(body['rpe'], 8);
      expect(body['painAreas'], ['knee']);
      expect(body['startedAt'], '2026-10-05T11:00:00.000Z');
      expect(body['endedAt'], '2026-10-05T11:02:00.000Z');
      expect(body['sets'], [
        {
          'exerciseId': squatId,
          'setIndex': 1,
          'reps': 11,
          'repSource': 'manual',
        },
      ]);

      // Kết quả: buổi 2 phút không tính streak.
      expect(find.text('Xong buổi tập!'), findsOneWidget);
      expect(find.text('Bạn đã tập 2 phút'), findsOneWidget);
      expect(
        find.text(
          'Buổi dưới 5 phút không tính streak. '
          'Lần sau cố thêm chút nữa nhé!',
        ),
        findsOneWidget,
      );
      expect(find.text('1/3 buổi'), findsOneWidget);
    });

    testWidgets('mất mạng: hiện banner, Thử lại gửi CÙNG clientId', (
      tester,
    ) async {
      final repo = FakeWorkoutRepository(
        exercises: testExercises,
        failuresBeforeSuccess: 1,
      );
      final h = WorkoutHarness(plan: planWith(const [squatItem]), repo: repo);
      await h.pump(tester, '/workout/$sessionId');
      await tapText(tester, 'Bắt đầu');
      await tapText(tester, 'Xong hiệp');
      await tapText(tester, 'Xem kết quả');

      expect(find.byKey(const ValueKey('retry-banner')), findsOneWidget);
      expect(find.textContaining('mất mạng'), findsOneWidget);
      expect(find.text('Xong buổi tập!'), findsNothing);

      await tapText(tester, 'Thử lại');
      expect(find.text('Xong buổi tập!'), findsOneWidget);
      expect(repo.sentRequests, hasLength(2));
      expect(repo.sentRequests[1].clientId, repo.sentRequests[0].clientId);
      expect(repo.sentRequests[1].endedAt, repo.sentRequests[0].endedAt);
    });
  });

  testWidgets('Kết quả hiện kỷ lục, huy hiệu và đạt mục tiêu tuần', (
    tester,
  ) async {
    final repo = FakeWorkoutRepository(
      exercises: testExercises,
      result: const WorkoutResult(
        workoutId: 'w1',
        localDate: '2026-10-05',
        durationSec: 754,
        countsForStreak: true,
        week: WeekProgress(
          weekStart: '2026-10-05',
          targetSessions: 3,
          completedSessions: 3,
          status: 'achieved',
        ),
        personalRecords: [
          PersonalRecord(
            exerciseId: squatId,
            nameVi: 'Squat',
            metric: 'max_reps',
            value: 12,
            previous: 10,
          ),
          PersonalRecord(
            exerciseId: plankId,
            nameVi: 'Plank',
            metric: 'max_duration',
            value: 45,
          ),
        ],
        newAchievements: [
          Achievement(
            code: 'week_goal',
            nameVi: 'Tuần trọn vẹn',
            descriptionVi: 'Đạt mục tiêu số buổi trong tuần',
          ),
        ],
      ),
    );
    final h = WorkoutHarness(plan: planWith(const [squatItem]), repo: repo);
    await h.pump(tester, '/workout/$sessionId');
    await tapText(tester, 'Bắt đầu');
    await tapText(tester, 'Xong hiệp');
    await tapText(tester, 'Xem kết quả');

    expect(find.text('Bạn đã tập 12 phút 34 giây'), findsOneWidget);
    expect(find.text('Buổi này được tính vào streak tuần.'), findsOneWidget);
    expect(find.text('3/3 buổi'), findsOneWidget);
    expect(find.textContaining('Đạt mục tiêu tuần'), findsOneWidget);
    expect(find.text('Kỷ lục mới'), findsOneWidget);
    expect(find.text('12 lần'), findsOneWidget);
    expect(find.text('Nhiều lần nhất · trước: 10 lần'), findsOneWidget);
    expect(find.text('45 giây'), findsOneWidget);
    expect(find.text('Giữ lâu nhất'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Tuần trọn vẹn'), 200);
    expect(find.text('Huy hiệu mới'), findsOneWidget);
    expect(find.text('Đạt mục tiêu số buổi trong tuần'), findsOneWidget);
  });

  testWidgets('Bài tracking = duration dùng đồng hồ bấm giờ', (tester) async {
    final h = WorkoutHarness(
      plan: planWith(const [plankItem]),
      factory: FakeRepSessionFactory(cameraSnapshot),
    );
    await h.pump(tester, '/workout/$sessionId');
    expect(find.text('1 hiệp × 30 giây'), findsOneWidget);
    await tapText(tester, 'Bắt đầu');

    final clock = find.byKey(const ValueKey('duration-clock'));
    expect(tester.widget<Text>(clock).data, '00:00');
    expect(find.text('Đếm bằng camera'), findsNothing);
    // Chưa bấm giờ thì chưa lưu được hiệp.
    await tester.tap(find.text('Xong hiệp'));
    await tester.pump();
    expect(h.container.read(activeWorkoutProvider)!.sets, isEmpty);

    await tester.tap(find.text('Bấm giờ'));
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(tester.widget<Text>(clock).data, '00:03');
    await tester.tap(find.text('Tạm dừng'));
    await tester.pump(const Duration(seconds: 5));
    expect(tester.widget<Text>(clock).data, '00:03');

    await tester.tap(find.text('+5s'));
    await tester.pump();
    expect(tester.widget<Text>(clock).data, '00:08');

    await tapText(tester, 'Xong hiệp');
    final set = h.container.read(activeWorkoutProvider)!.sets.single;
    expect(set.toJson(), {
      'exerciseId': plankId,
      'setIndex': 1,
      'durationSec': 8,
      'repSource': 'manual',
    });
    expect(find.text('Buổi tập vừa rồi như thế nào?'), findsOneWidget);
  });

  testWidgets('Bài theo tạ gửi weightKg', (tester) async {
    final h = WorkoutHarness(
      plan: planWith(const [
        ItemView(exerciseId: gobletId, nameVi: 'Squat ôm tạ', sets: 1, reps: 8),
      ]),
    );
    await h.pump(tester, '/workout/$sessionId');
    await tapText(tester, 'Bắt đầu');
    await tester.tap(find.bySemanticsLabel('Tăng Tạ (kg)'));
    await tester.tap(find.bySemanticsLabel('Tăng Tạ (kg)'));
    await tester.pump();
    await tapText(tester, 'Xong hiệp');
    expect(h.container.read(activeWorkoutProvider)!.sets.single.toJson(), {
      'exerciseId': gobletId,
      'setIndex': 1,
      'reps': 8,
      'weightKg': 2.0,
      'repSource': 'manual',
    });
  });

  group('Đếm bằng camera', () {
    Future<WorkoutHarness> openCounting(
      WidgetTester tester, {
      int sets = 1,
    }) async {
      final factory = FakeRepSessionFactory(cameraSnapshot);
      final h = WorkoutHarness(
        plan: planWith([
          ItemView(exerciseId: squatId, nameVi: 'Squat', sets: sets, reps: 10),
        ]),
        factory: factory,
      );
      await h.pump(tester, '/workout/$sessionId');
      await tapText(tester, 'Bắt đầu');
      await tapText(tester, 'Đếm bằng camera');
      expect(
        find.text('Đặt điện thoại để camera đếm giúp bạn'),
        findsOneWidget,
      );
      expect(find.text('Mặc quần gọn để thấy rõ gối.'), findsOneWidget);
      await tapText(tester, 'Tôi đã sẵn sàng');
      return h;
    }

    FakeRepSessionFactory factoryOf(WorkoutHarness h) =>
        h.factory as FakeRepSessionFactory;

    testWidgets('Tự mở camera: bấm Bắt đầu là vào màn đặt camera, quay lại thì không mở lại hiệp đó', (
      tester,
    ) async {
      final h = WorkoutHarness(
        plan: planWith([
          ItemView(exerciseId: squatId, nameVi: 'Squat', sets: 2, reps: 10),
        ]),
        factory: FakeRepSessionFactory(cameraSnapshot),
        autoCamera: true,
      );
      await h.pump(tester, '/workout/$sessionId');
      await tapText(tester, 'Bắt đầu');
      expect(find.text('Đặt điện thoại để camera đếm giúp bạn'), findsOneWidget);

      // Quay lại: về màn tập, đếm tay được, không tự mở lại
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).last);
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Đặt điện thoại để camera đếm giúp bạn'), findsNothing);
      expect(find.text('Đếm bằng camera'), findsOneWidget);
    });

    testWidgets('Bài không đếm được bằng camera thì không tự mở', (tester) async {
      final h = WorkoutHarness(
        plan: planWith([
          ItemView(exerciseId: squatId, nameVi: 'Squat', sets: 1, reps: 10),
        ]),
        autoCamera: true,
      );
      await h.pump(tester, '/workout/$sessionId');
      await tapText(tester, 'Bắt đầu');
      await tester.pump(const Duration(seconds: 2)); // câu "bắt đầu" hẹn 1,2 giây
      expect(find.text('Đặt điện thoại để camera đếm giúp bạn'), findsNothing);
    });

    testWidgets('sửa số thì camera_corrected, giữ nguyên thì camera', (
      tester,
    ) async {
      final h = await openCounting(tester, sets: 2);
      final first = factoryOf(h).created.single;
      expect(first.starts, 1);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('camera-rep-count')))
            .data,
        '8',
      );
      expect(find.byKey(const ValueKey('form-warning')), findsOneWidget);

      await tapText(tester, 'Xong hiệp');
      expect(first.stops, greaterThanOrEqualTo(1));
      expect(find.text('Camera đếm được 8 lần'), findsOneWidget);
      expect(find.text('75/100'), findsOneWidget);
      expect(find.text('Lần 3: Xuống chưa đủ sâu'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Tăng Số lần'));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('confirm-reps'))).data,
        '9',
      );
      await tapText(tester, 'Lưu hiệp');

      // Hiệp 2: giữ nguyên số camera đếm.
      expect(find.text('Hiệp 2/2 · Mục tiêu 10 lần'), findsOneWidget);
      await tapText(tester, 'Đếm bằng camera');
      await tapText(tester, 'Tôi đã sẵn sàng');
      await tapText(tester, 'Xong hiệp');
      await tapText(tester, 'Lưu hiệp');

      expect(find.text('Buổi tập vừa rồi như thế nào?'), findsOneWidget);
      final sets = h.container
          .read(activeWorkoutProvider)!
          .sets
          .map((s) => s.toJson())
          .toList();
      const camera = {
        'repsDetected': 8,
        'cvVersion': 2,
        'avgConfidence': 0.82,
        'formScore': 75,
        'formIssues': [
          {'repIndex': 3, 'code': 'shallow_depth', 'severity': 2},
        ],
      };
      expect(sets, [
        {
          'exerciseId': squatId,
          'setIndex': 1,
          'reps': 9,
          'repSource': 'camera_corrected',
          ...camera,
        },
        {
          'exerciseId': squatId,
          'setIndex': 2,
          'reps': 8,
          'repSource': 'camera',
          ...camera,
        },
      ]);
      expect(factoryOf(h).created, hasLength(2));
      expect(factoryOf(h).created.every((s) => s.stops >= 1), isTrue);
    });

    testWidgets('đủ số lần mục tiêu thì tự kết thúc hiệp, không cần bấm Xong', (
      tester,
    ) async {
      final h = await openCounting(tester, sets: 2);
      final session = factoryOf(h).created.single;
      session.emit(const RepSnapshot(
        repCount: 10,
        averageConfidence: 0.9,
        formScore: 90,
        status: RepCountingStatus.running,
      ));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(session.stops, greaterThanOrEqualTo(1));
      expect(find.text('Camera đếm được 10 lần'), findsOneWidget);
    });

    testWidgets('tích "Không hỏi lại hôm nay" thì hiệp sau vào đếm luôn', (
      tester,
    ) async {
      final skip = MemoryCameraSetupSkip();
      final factory = FakeRepSessionFactory(cameraSnapshot);
      final h = WorkoutHarness(
        plan: planWith([
          ItemView(exerciseId: squatId, nameVi: 'Squat', sets: 2, reps: 10),
        ]),
        factory: factory,
        setupSkip: skip,
      );
      await h.pump(tester, '/workout/$sessionId');
      await tapText(tester, 'Bắt đầu');
      await tapText(tester, 'Đếm bằng camera');
      await tester.tap(find.byKey(const ValueKey('camera-skip-today')));
      await tester.pump();
      await tapText(tester, 'Tôi đã sẵn sàng');
      expect(await skip.skippedDate(), isNotNull);
      await tapText(tester, 'Xong hiệp');
      await tapText(tester, 'Lưu hiệp');
      // Bỏ qua thời gian nghỉ nếu có
      final skipRest = find.text('Bỏ qua nghỉ');
      if (skipRest.evaluate().isNotEmpty) await tapText(tester, 'Bỏ qua nghỉ');
      await tapText(tester, 'Đếm bằng camera');
      // Hiệp 2: không còn màn Đặt camera
      expect(find.text('Tôi đã sẵn sàng'), findsNothing);
      expect(find.byKey(const ValueKey('camera-rep-count')), findsOneWidget);
    });

    testWidgets('Chuyển sang đếm tay tắt camera, không lưu hiệp', (
      tester,
    ) async {
      final h = await openCounting(tester);
      final session = factoryOf(h).created.single;
      expect(session.stops, 0);

      await tapText(tester, 'Chuyển sang đếm tay');
      expect(session.stops, 1);
      expect(find.text('Hiệp 1/1 · Mục tiêu 10 lần'), findsOneWidget);
      expect(h.container.read(activeWorkoutProvider)!.sets, isEmpty);
    });

    testWidgets('Bấm back khi đang đếm cũng tắt camera', (tester) async {
      final h = await openCounting(tester);
      final session = factoryOf(h).created.single;

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      await navigator.maybePop();
      await tester.pumpAndSettle();
      expect(session.stops, 1);
      expect(find.text('Hiệp 1/1 · Mục tiêu 10 lần'), findsOneWidget);
      expect(h.container.read(activeWorkoutProvider)!.sets, isEmpty);
    });

    testWidgets('Từ chối quyền camera thì hiện lỗi, vẫn đếm tay được', (
      tester,
    ) async {
      final factory = FakeRepSessionFactory(cameraSnapshot);
      final h = WorkoutHarness(
        plan: planWith(const [squatItem]),
        factory: factory,
        permission: FakePermissionGate(CameraPermissionResult.denied),
      );
      await h.pump(tester, '/workout/$sessionId');
      await tapText(tester, 'Bắt đầu');
      await tapText(tester, 'Đếm bằng camera');
      await tapText(tester, 'Tôi đã sẵn sàng');
      expect(find.textContaining('cần quyền camera'), findsOneWidget);
      expect(factory.created, isEmpty);
      await tapText(tester, 'Tự đếm tay');
      expect(find.text('Đếm tay: xong hiệp'), findsOneWidget);
    });
  });
}
