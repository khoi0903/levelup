import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/app/theme.dart';
import 'package:fitness_app/core/constants/app_strings.dart';
import 'package:fitness_app/core/widgets/primary_button.dart';

void main() {
  testWidgets(
      'Nút "Tiếp tục" ở màn mục tiêu bị vô hiệu khi chưa chọn gì và kích hoạt khi đã chọn',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: createAppRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Màn 1/7 - Goal
    expect(find.text(AppStrings.goalTitle), findsOneWidget);

    final continueBtnFinder = find.widgetWithText(PrimaryButton, AppStrings.btnContinue);
    expect(continueBtnFinder, findsOneWidget);

    // Khi chưa chọn mục tiêu, nút bị vô hiệu (onPressed == null)
    PrimaryButton primaryBtn = tester.widget(continueBtnFinder);
    expect(primaryBtn.onPressed, isNull);

    // Thử bấm khi bị vô hiệu, màn hình không đổi
    await tester.tap(continueBtnFinder);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.goalTitle), findsOneWidget);
    expect(find.text(AppStrings.bodyTitle), findsNothing);

    // Chọn một mục tiêu (Giảm mỡ)
    await tester.tap(find.text(AppStrings.goalLoseFatTitle));
    await tester.pumpAndSettle();

    // Nút đã được kích hoạt (onPressed != null)
    primaryBtn = tester.widget(continueBtnFinder);
    expect(primaryBtn.onPressed, isNotNull);

    // Bấm Tiếp tục thành công chuyển sang màn OB-Body
    await tester.tap(continueBtnFinder);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.bodyTitle), findsOneWidget);
  });

  testWidgets('Onboarding flow navigates successfully from Main to OB-Start with selections',
      (WidgetTester tester) async {
    // Tăng kích thước màn hình để tránh overflow trong test
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: createAppRouter(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Màn Main / Goal (1/7)
    expect(find.text(AppStrings.goalTitle), findsOneWidget);
    expect(find.text(AppStrings.goalStep), findsOneWidget);

    // Chọn mục tiêu rồi bấm Tiếp tục
    await tester.tap(find.text(AppStrings.goalLoseFatTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.btnContinue));
    await tester.pumpAndSettle();

    // 2. Màn OB-Body (2/7)
    expect(find.text(AppStrings.bodyTitle), findsOneWidget);
    expect(find.text(AppStrings.bodyStep), findsOneWidget);

    // Điền chiều cao và cân nặng hợp lệ
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(1), '175'); // heightCm
    await tester.enterText(textFields.at(2), '72');  // weightKg
    await tester.pumpAndSettle();

    // Bấm Tiếp tục sang OB-Training
    await tester.tap(find.text(AppStrings.btnContinue));
    await tester.pumpAndSettle();

    // 3. Màn OB-Training (3/7)
    expect(find.text(AppStrings.trainingTitle), findsOneWidget);
    expect(find.text(AppStrings.trainingStep), findsOneWidget);

    // Chọn kinh nghiệm và nơi tập
    await tester.tap(find.text(AppStrings.expBeginner));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.locationHome));
    await tester.pumpAndSettle();

    // Bấm Tiếp tục sang OB-Schedule
    await tester.tap(find.text(AppStrings.btnContinue));
    await tester.pumpAndSettle();

    // 4. Màn OB-Schedule (4/7)
    expect(find.text(AppStrings.scheduleTitle), findsOneWidget);
    expect(find.text(AppStrings.scheduleStep), findsOneWidget);

    // Chọn ít nhất 1 ngày rảnh, khung giờ và thời lượng
    await tester.tap(find.text(AppStrings.weekdayMon));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.slotEveningTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.duration1015));
    await tester.pumpAndSettle();

    // Bấm Tiếp tục sang OB-Why
    await tester.tap(find.text(AppStrings.btnContinue));
    await tester.pumpAndSettle();

    // 5. Màn OB-Why (5/7)
    expect(find.text(AppStrings.whyTitle), findsOneWidget);
    expect(find.text(AppStrings.whyStep), findsOneWidget);

    // Bấm Tiếp tục sang OB-Coach
    await tester.tap(find.text(AppStrings.btnContinue));
    await tester.pumpAndSettle();

    // 6. Màn OB-Coach (6/7)
    expect(find.text(AppStrings.coachTitle), findsOneWidget);
    expect(find.text(AppStrings.coachStep), findsOneWidget);
    expect(find.text(AppStrings.btnCreateMyPlan), findsOneWidget);

    // Chọn phong cách coach
    await tester.tap(find.text(AppStrings.coachSupportiveTitle));
    await tester.pumpAndSettle();

    // Bấm Tạo kế hoạch của tôi sang OB-Plan
    await tester.tap(find.text(AppStrings.btnCreateMyPlan));
    await tester.pumpAndSettle();

    // 7. Màn OB-Plan (7/7)
    expect(find.text(AppStrings.planTitle), findsOneWidget);
    expect(find.text(AppStrings.planStep), findsOneWidget);
    expect(find.text(AppStrings.btnContinue), findsOneWidget);

    // Bấm Tiếp tục sang OB-Notify
    await tester.tap(find.text(AppStrings.btnContinue));
    await tester.pumpAndSettle();

    // 8. Màn OB-Notify
    expect(find.text(AppStrings.notifyTitle), findsOneWidget);
    expect(find.text(AppStrings.btnEnableNotification), findsOneWidget);

    // Bấm Bật thông báo sang OB-Start
    await tester.tap(find.text(AppStrings.btnEnableNotification));
    await tester.pumpAndSettle();

    // 9. Màn OB-Start
    expect(find.text(AppStrings.startTitle), findsOneWidget);
    expect(find.text(AppStrings.btnStart5Min), findsOneWidget);
    expect(find.text(AppStrings.btnScheduleFirstSession), findsOneWidget);
  });
}
