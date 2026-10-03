import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/app/theme.dart';
import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/core/constants/app_strings.dart';
import 'package:fitness_app/core/widgets/primary_button.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_onboarding_repository.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_plan_repository.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';

void main() {
  group('App Bootstrap Flow (GET /me)', () {
    testWidgets('404 ONBOARDING_REQUIRED điều hướng vào màn Onboarding (Goal)',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(
              FakeUserRepository(
                errorToThrow: const ApiException(
                  code: 'ONBOARDING_REQUIRED',
                  statusCode: 404,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: createAppRouter(initialLocation: '/'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Vào màn Onboarding Goal
      expect(find.text(AppStrings.goalTitle), findsOneWidget);
    });

    testWidgets('200 điều hướng vào màn Home hiển thị tên và streak người dùng',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(
              FakeUserRepository(
                meResponse: const MeResponse(
                  id: 'user-123',
                  displayName: 'Nguyễn Văn A',
                  timezone: 'Asia/Ho_Chi_Minh',
                  localDate: 'Thứ Bảy, 03/10',
                  weekStart: '2026-09-28',
                  profile: UserProfile(goal: 'lose_fat'),
                  streak: UserStreak(currentWeeks: 4, bestWeeks: 6),
                ),
              ),
            ),
            planRepositoryProvider.overrideWithValue(FakePlanRepository()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: createAppRouter(initialLocation: '/'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Vào màn Home
      expect(find.text('Chào buổi chiều, Nguyễn Văn A'), findsOneWidget);
      expect(find.text('4 tuần'), findsOneWidget);
    });

    testWidgets('Lỗi mạng hiển thị "Không kết nối được máy chủ" kèm nút Thử lại',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(
              FakeUserRepository(
                errorToThrow: const ApiException(
                  code: 'NETWORK_ERROR',
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: createAppRouter(initialLocation: '/'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Màn báo lỗi kết nối
      expect(find.text('Không kết nối được máy chủ'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      // Bấm nút Thử lại
      await tester.tap(find.text('Thử lại'));
      await tester.pump();
    });

    testWidgets(
        'Lỗi khác (401, 500) hiển thị "Có lỗi xảy ra (mã lỗi)" kèm nút Thử lại',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(
              FakeUserRepository(
                errorToThrow: const ApiException(
                  code: 'INTERNAL_SERVER_ERROR',
                  statusCode: 500,
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: createAppRouter(initialLocation: '/'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Màn báo lỗi máy chủ kèm mã lỗi
      expect(find.text('Có lỗi xảy ra (500)'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      await tester.pump();
    });
  });

  group('Onboarding Flow and Validation', () {
    testWidgets(
        'Nút "Tiếp tục" ở màn mục tiêu chỉ bật khi đã chọn mục tiêu VÀ tên khác rỗng',
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
            routerConfig: createAppRouter(initialLocation: '/onboarding/goal'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Màn 1/7 - Goal
      expect(find.text(AppStrings.goalTitle), findsOneWidget);

      final continueBtnFinder =
          find.widgetWithText(PrimaryButton, AppStrings.btnContinue);
      expect(continueBtnFinder, findsOneWidget);

      // 1. Khi chưa nhập tên và chưa chọn mục tiêu, nút bị vô hiệu
      PrimaryButton primaryBtn = tester.widget(continueBtnFinder);
      expect(primaryBtn.onPressed, isNull);

      // 2. Chỉ chọn mục tiêu (chưa nhập tên) -> nút vẫn bị vô hiệu
      await tester.tap(find.text(AppStrings.goalLoseFatTitle));
      await tester.pumpAndSettle();
      primaryBtn = tester.widget(continueBtnFinder);
      expect(primaryBtn.onPressed, isNull);

      // 3. Nhập tên toàn khoảng trắng -> nút vẫn bị vô hiệu
      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, '   ');
      await tester.pumpAndSettle();
      primaryBtn = tester.widget(continueBtnFinder);
      expect(primaryBtn.onPressed, isNull);

      // 4. Nhập tên hợp lệ (đã chọn mục tiêu) -> nút được kích hoạt
      await tester.enterText(nameField, 'Minh Test');
      await tester.pumpAndSettle();
      primaryBtn = tester.widget(continueBtnFinder);
      expect(primaryBtn.onPressed, isNotNull);

      // 5. Bấm Tiếp tục thành công chuyển sang màn OB-Body
      await tester.tap(continueBtnFinder);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.bodyTitle), findsOneWidget);
    });

    testWidgets(
        'Onboarding flow navigates successfully from Main to OB-Start with selections',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            planRepositoryProvider.overrideWithValue(FakePlanRepository()),
            onboardingRepositoryProvider
                .overrideWithValue(FakeOnboardingRepository()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: createAppRouter(initialLocation: '/onboarding/goal'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Màn Main / Goal (1/7)
      expect(find.text(AppStrings.goalTitle), findsOneWidget);
      expect(find.text(AppStrings.goalStep), findsOneWidget);

      // Nhập tên và chọn mục tiêu rồi bấm Tiếp tục
      await tester.enterText(find.byType(TextField).first, 'Minh Test');
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
      await tester.enterText(textFields.at(2), '72'); // weightKg
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

      // Bấm Tạo kế hoạch của tôi sang OB-Plan (gọi completeOnboarding)
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

    testWidgets('Lỗi 400 từ POST /onboarding hiển thị thông báo đúng trường bị sai',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            onboardingRepositoryProvider.overrideWithValue(
              FakeOnboardingRepository(
                errorToThrow: const ApiException(
                  code: 'VALIDATION_ERROR',
                  statusCode: 400,
                  fields: {
                    'heightCm': 'Chiều cao không hợp lệ',
                    'weightKg': 'Cân nặng không hợp lệ',
                  },
                ),
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: createAppRouter(initialLocation: '/onboarding/coach'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Chọn phong cách coach
      await tester.tap(find.text(AppStrings.coachSupportiveTitle));
      await tester.pumpAndSettle();

      // Bấm Tạo kế hoạch
      await tester.tap(find.text(AppStrings.btnCreateMyPlan));
      await tester.pumpAndSettle();

      // Kiểm tra thông báo lỗi trường sai xuất hiện trong SnackBar
      expect(find.textContaining('heightCm: Chiều cao không hợp lệ'), findsOneWidget);
      expect(find.textContaining('weightKg: Cân nặng không hợp lệ'), findsOneWidget);
      // Vẫn ở lại màn Coach
      expect(find.text(AppStrings.coachTitle), findsOneWidget);
    });
  });
}
