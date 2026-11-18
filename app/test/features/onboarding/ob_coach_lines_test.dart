import 'package:fitness_app/features/onboarding/domain/models/onboarding_models.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_body_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_goal_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_schedule_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_training_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget screen, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
  void Function(OnboardingController c)? setup,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  setup?.call(container.read(onboardingControllerProvider.notifier));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

String _coachText(WidgetTester tester) {
  final w = tester.widget<Text>(
    find.byKey(const ValueKey('coach-reaction-text')).last,
  );
  return w.textSpan!.toPlainText();
}

void main() {
  testWidgets('màn mục tiêu: câu coach đổi ngay theo lựa chọn', (tester) async {
    await _pump(tester, const ObGoalScreen());
    expect(find.byKey(const ValueKey('coach-reaction-text')), findsNothing);

    await tester.tap(find.text('Giảm mỡ'));
    await tester.pumpAndSettle();
    expect(_coachText(tester), startsWith('Giảm mỡ bền vững.'));

    await tester.tap(find.text('Tăng cơ'));
    await tester.pumpAndSettle();
    expect(_coachText(tester), startsWith('Tăng cơ chắc chắn.'));
  });

  testWidgets('màn số đo: BMI hiện ngay khi nhập, có thang và câu coach', (
    tester,
  ) async {
    await _pump(tester, const ObBodyScreen());
    expect(find.byKey(const ValueKey('ob-bmi-live')), findsNothing);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), '170');
    await tester.enterText(fields.at(2), '62');
    await tester.pumpAndSettle();

    expect(find.text('BMI 21.5'), findsOneWidget);
    expect(find.text('Trong khoảng chuẩn'), findsOneWidget);
    expect(find.byKey(const ValueKey('ob-bmi-marker')), findsOneWidget);
    expect(_coachText(tester), startsWith('Cân nặng đang rất ổn.'));

    await tester.enterText(fields.at(2), '80');
    await tester.pumpAndSettle();
    expect(find.text('BMI 27.7'), findsOneWidget);
    expect(find.text('Cao hơn khoảng chuẩn'), findsOneWidget);
  });

  testWidgets('màn lịch: giờ riêng từng ngày, chỉ lưu ngày đã đổi', (
    tester,
  ) async {
    final container = await _pump(
      tester,
      const ObScheduleScreen(),
      setup: (c) {
        c.toggleWeekday(1);
        c.toggleWeekday(3);
        c.setTimeSlot(TimeSlot.evening);
      },
    );
    expect(find.text('Giờ riêng từng ngày'), findsOneWidget);
    expect(find.text('Thứ Hai'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('day-times-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Thứ Hai'), findsOneWidget);
    expect(find.text('Thứ Tư'), findsOneWidget);
    expect(find.text('18:30'), findsNWidgets(2));

    container
        .read(onboardingControllerProvider.notifier)
        .setDayTime(3, '07:00');
    await tester.pumpAndSettle();
    expect(find.text('07:00'), findsOneWidget);
    expect(find.text('Đã đặt riêng 1 ngày'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('day-time-reset-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-time-reset-3')));
    await tester.pumpAndSettle();
    expect(container.read(onboardingControllerProvider).dayTimes, isEmpty);

    // Chạm giờ mở đồng hồ chọn giờ.
    await tester.ensureVisible(find.byKey(const ValueKey('day-time-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('day-time-1')));
    await tester.pumpAndSettle();
    expect(find.text('Giờ tập Thứ Hai'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(container.read(onboardingControllerProvider).dayTimes, isEmpty);
  });

  testWidgets('màn tập luyện: câu coach theo mục vừa chạm', (tester) async {
    await _pump(
      tester,
      const ObTrainingScreen(),
      setup: (c) => c.toggleInjury(BodyArea.knee),
    );
    expect(_coachText(tester), contains('tránh các bài đè lên gối'));

    await tester.tap(find.text('Ở nhà'));
    await tester.pumpAndSettle();
    expect(_coachText(tester), startsWith('Tập tại nhà, không cần dụng cụ.'));
  });

  // Màn "Tập luyện" không có ở đây: hình chọn chỗ đau (body_figure.dart)
  // đã tràn ngang ở 320 px từ trước, không thuộc phần thay đổi này.
  group('không tràn ở 320 px, chữ 1.3', () {
    const size = Size(320, 640);

    testWidgets('mục tiêu', (tester) async {
      await _pump(
        tester,
        const ObGoalScreen(),
        size: size,
        textScale: 1.3,
        setup: (c) => c.selectGoal(UserGoal.lose_fat),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('số đo + BMI', (tester) async {
      await _pump(
        tester,
        const ObBodyScreen(),
        size: size,
        textScale: 1.3,
        setup: (c) => c.updateBodyInfo(heightCm: 160, startWeightKg: 90),
      );
      expect(find.byKey(const ValueKey('ob-bmi-live')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lịch tập với giờ riêng mở sẵn', (tester) async {
      await _pump(
        tester,
        const ObScheduleScreen(dayTimesInitiallyExpanded: true),
        size: size,
        textScale: 1.3,
        setup: (c) {
          for (final d in [1, 3, 5, 7]) {
            c.toggleWeekday(d);
          }
          c.setTimeSlot(TimeSlot.late_evening);
          c.setSessionMinutes(45);
          c.setDayTime(7, '08:30');
        },
      );
      expect(find.text('Chủ Nhật'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
