import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/workout/domain/models/workout_session_state.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test_helpers.dart';

const squatItem = ItemView(
  exerciseId: squatId,
  nameVi: 'Squat',
  sets: 2,
  reps: 10,
);

const plankItem = ItemView(
  exerciseId: plankId,
  nameVi: 'Plank',
  sets: 2,
  durationSec: 30,
);

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  group('Đổi bài tập (Swap exercise)', () {
    testWidgets('Mở sheet hiện danh sách bài thay thế', (tester) async {
      final h = WorkoutHarness(plan: planWith(const [squatItem]));
      await h.pump(tester, '/workout/$sessionId');

      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('Đổi'), findsOneWidget);

      await tapText(tester, 'Đổi');

      expect(find.text('Đổi bài Squat'), findsOneWidget);
      expect(find.text('Squat ôm tạ'), findsOneWidget);
      expect(find.text('Plank'), findsOneWidget);
      expect(find.text('Không gợi ý bài này nữa'), findsOneWidget);
      expect(find.text('Hỏi coach gợi ý thêm'), findsOneWidget);
    });

    testWidgets('Chọn bài gọi swap đúng from/to/remember và cập nhật UI', (
      tester,
    ) async {
      final h = WorkoutHarness(plan: planWith(const [squatItem]));
      await h.pump(tester, '/workout/$sessionId');

      await tapText(tester, 'Đổi');

      // Tích ô "Không gợi ý bài này nữa"
      await tapText(tester, 'Không gợi ý bài này nữa');

      // Chọn bài "Squat ôm tạ"
      await tapText(tester, 'Squat ôm tạ');

      expect(h.repo.sentSwaps.length, 1);
      final swapCall = h.repo.sentSwaps.single;
      expect(swapCall['sessionId'], sessionId);
      expect(swapCall['fromExerciseId'], squatId);
      expect(swapCall['toExerciseId'], gobletId);
      expect(swapCall['remember'], isTrue);

      // SnackBar hiển thị
      expect(find.text('Đã đổi Squat → Squat ôm tạ'), findsOneWidget);

      // Màn hình bắt đầu cập nhật tên bài mới
      expect(find.text('Squat ôm tạ'), findsOneWidget);
    });

    testWidgets('409 SESSION_NOT_PLANNED hiện thông báo đúng', (tester) async {
      final h = WorkoutHarness(plan: planWith(const [squatItem]));
      h.repo.swapFailure = const ApiException(
        code: 'SESSION_NOT_PLANNED',
        statusCode: 409,
      );

      await h.pump(tester, '/workout/$sessionId');
      await tapText(tester, 'Đổi');
      await tapText(tester, 'Squat ôm tạ');

      expect(
        find.text('Buổi này đã tập hoặc đã bỏ, không đổi được nữa'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Buổi extra đổi trong máy không gọi API và không có ô không gợi ý nữa',
      (tester) async {
        const extraId = 'extra-123';
        final h = WorkoutHarness(plan: planWith(const [squatItem]));

        // Khởi tạo buổi extra trong provider
        const extraSession = SessionView(
          id: extraId,
          scheduledDate: '2026-10-05',
          scheduledTime: '18:00',
          title: 'Tập thêm',
          durationMin: 15,
          variant: 'normal',
          status: 'planned',
          items: [squatItem],
        );
        final extraSetup = WorkoutSetup(
          session: extraSession,
          items: [WorkoutPlanItem.from(squatItem, testExercises[0])],
        );

        await h.pump(tester, '/workout/$extraId');
        h.container.read(extraWorkoutSetupProvider.notifier).state = extraSetup;
        h.container.invalidate(
          workoutSetupProvider((sessionId: extraId, quick5: false)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Squat'), findsOneWidget);
        await tapText(tester, 'Đổi');

        // Buổi extra không có ô "Không gợi ý bài này nữa"
        expect(find.text('Không gợi ý bài này nữa'), findsNothing);

        // Đổi sang Plank
        await tapText(tester, 'Plank');

        // Không gọi backend swap API
        expect(h.repo.sentSwaps, isEmpty);

        // Hiện SnackBar và cập nhật bài trong máy
        expect(find.text('Đã đổi Squat → Plank'), findsOneWidget);
        expect(find.text('Plank'), findsOneWidget);
      },
    );

    testWidgets(
      'Màn đang tập: hiện nút khi chưa tập hiệp nào, ẩn nút khi đã ghi hiệp',
      (tester) async {
        final h = WorkoutHarness(plan: planWith(const [squatItem]));
        await h.pump(tester, '/workout/$sessionId');

        await tapText(tester, 'Bắt đầu');

        // Lúc mới bắt đầu, chưa ghi hiệp nào: nút "Đổi bài này" hiện
        expect(find.text('Đổi bài này'), findsOneWidget);

        // Ghi 1 hiệp
        await tapText(tester, 'Xong hiệp');

        // Đã ghi hiệp: nút "Đổi bài này" ẩn
        expect(find.text('Đổi bài này'), findsNothing);
      },
    );

    testWidgets(
      'Màn đang tập: đổi bài thành công cập nhật WorkoutSessionState và draft',
      (tester) async {
        final h = WorkoutHarness(plan: planWith(const [squatItem]));
        await h.pump(tester, '/workout/$sessionId');
        await tapText(tester, 'Bắt đầu');

        expect(find.text('Squat'), findsOneWidget);
        expect(find.text('Hiệp 1/2 · Mục tiêu 10 lần'), findsOneWidget);

        await tapText(tester, 'Đổi bài này');
        expect(find.text('Đổi bài Squat'), findsOneWidget);

        await tapText(tester, 'Plank');

        expect(find.text('Đã đổi Squat → Plank'), findsOneWidget);
        expect(find.text('Plank'), findsOneWidget);

        // Plank tính theo thời gian: mục tiêu chuyển sang 30 giây, vẫn giữ 2 hiệp
        expect(find.text('Hiệp 1/2 · Mục tiêu 30 giây'), findsOneWidget);

        final state = h.container.read(activeWorkoutProvider);
        expect(state?.currentItem?.exerciseId, plankId);
        expect(state?.currentItem?.nameVi, 'Plank');
        expect(state?.currentItem?.sets, 2);
        expect(state?.currentItem?.durationSec, 30);
        expect(state?.currentItem?.reps, isNull);

        await tester.pump(const Duration(seconds: 2));
      },
    );

    testWidgets(
      'Sheet: lỗi hiện mapErrorMessage + thử lại, rỗng hiện thông báo',
      (tester) async {
        final h = WorkoutHarness(plan: planWith(const [squatItem]));
        h.repo.alternativesFailure = const ApiException(code: 'NETWORK_ERROR');

        await h.pump(tester, '/workout/$sessionId');
        await tapText(tester, 'Đổi');

        // Hiện thông báo lỗi mạng
        expect(
          find.text(
            'Không kết nối được máy chủ. Vui lòng kiểm tra kết nối mạng.',
          ),
          findsOneWidget,
        );
        expect(find.text('Thử lại'), findsOneWidget);

        // Thử lại thành công
        h.repo.alternativesFailure = null;
        await tapText(tester, 'Thử lại');

        expect(find.text('Squat ôm tạ'), findsOneWidget);

        // Đóng sheet
        await tester.tap(find.byTooltip('Đóng'));
        await tester.pumpAndSettle();

        // Trường hợp rỗng
        h.repo.fakeAlternatives = [];
        await tapText(tester, 'Đổi');
        expect(find.text('Chưa có bài thay thế phù hợp'), findsOneWidget);
      },
    );

    testWidgets('Hỏi coach gợi ý thêm mở tab Coach với câu soạn sẵn', (
      tester,
    ) async {
      final h = WorkoutHarness(plan: planWith(const [squatItem]));
      await h.pump(tester, '/workout/$sessionId');

      await tapText(tester, 'Đổi');
      expect(find.text('Hỏi coach gợi ý thêm'), findsOneWidget);

      await tapText(tester, 'Hỏi coach gợi ý thêm');

      // Chuyển sang màn Coach và ô nhập có câu soạn sẵn
      expect(
        find.text(
          'Mình không thích bài Squat, gợi ý bài khác cùng nhóm cơ giúp mình',
        ),
        findsOneWidget,
      );
    });
    testWidgets('Buổi đã bị chốt bỏ (skipped): ẩn nút Đổi, gợi ý tập thêm', (
      tester,
    ) async {
      final h = WorkoutHarness(
        plan: planWith(const [squatItem], status: 'skipped'),
      );
      await h.pump(tester, '/workout/$sessionId');

      expect(find.text('Squat'), findsOneWidget);
      expect(find.text('Đổi'), findsNothing);
      expect(
        find.text(
          'Buổi này đã qua và được tính là bỏ. Bạn có thể chọn tập thêm.',
        ),
        findsOneWidget,
      );
      expect(find.text('Tập thêm'), findsOneWidget);
    });

    test('pickNextSession bỏ qua buổi skipped', () {
      const done = SessionView(
        id: 'mon',
        scheduledDate: '2026-10-05',
        scheduledTime: '06:00',
        title: 'T2',
        durationMin: 15,
        status: 'completed',
        variant: 'normal',
        items: [],
      );
      const skipped = SessionView(
        id: 'tue',
        scheduledDate: '2026-10-06',
        scheduledTime: '06:00',
        title: 'T3',
        durationMin: 15,
        status: 'skipped',
        variant: 'light',
        items: [],
      );
      const plan = PlanView(
        id: 'plan',
        weekStart: '2026-10-05',
        status: 'active',
        targetSessions: 2,
        sessions: [done, skipped],
      );
      expect(isSessionOpen(skipped), isFalse);
      expect(pickNextSession(plan, '2026-10-07')?.id, 'mon');
    });
  });
}
