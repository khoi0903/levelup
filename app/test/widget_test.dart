import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/app/theme.dart';
import 'package:fitness_app/core/constants/app_strings.dart';

void main() {
  testWidgets('Onboarding flow navigates successfully from Main to OB-Start',
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
          routerConfig: appRouter,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. Màn Main / Goal (1/7)
    expect(find.text(AppStrings.goalTitle), findsOneWidget);
    expect(find.text(AppStrings.goalStep), findsOneWidget);
    expect(find.text(AppStrings.btnContinue), findsOneWidget);

    // Bấm Tiếp tục sang OB-Body
    await tester.tap(find.text(AppStrings.btnContinue));
    await tester.pumpAndSettle();

    // 2. Màn OB-Body (2/7)
    expect(find.text(AppStrings.bodyTitle), findsOneWidget);
    expect(find.text(AppStrings.bodyStep), findsOneWidget);

    // Bấm Tiếp tục sang OB-Training
    await tester.tap(find.text(AppStrings.btnContinue));
    await tester.pumpAndSettle();

    // 3. Màn OB-Training (3/7)
    expect(find.text(AppStrings.trainingTitle), findsOneWidget);
    expect(find.text(AppStrings.trainingStep), findsOneWidget);

    // Bấm Tiếp tục sang OB-Schedule
    await tester.tap(find.text(AppStrings.btnContinue));
    await tester.pumpAndSettle();

    // 4. Màn OB-Schedule (4/7)
    expect(find.text(AppStrings.scheduleTitle), findsOneWidget);
    expect(find.text(AppStrings.scheduleStep), findsOneWidget);

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
