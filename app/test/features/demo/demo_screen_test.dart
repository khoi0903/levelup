import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:fitness_app/features/auth/domain/models/auth_user.dart';
import 'package:fitness_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:fitness_app/features/demo/data/repositories/fake_demo_repository.dart';
import 'package:fitness_app/features/demo/presentation/controllers/demo_controller.dart';
import 'package:fitness_app/features/demo/presentation/screens/demo_screen.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_plan_repository.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/streak/data/repositories/fake_streak_repository.dart';
import 'package:fitness_app/features/streak/presentation/controllers/streak_controller.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoScreen & Simulation Trigger', () {
    testWidgets('Tapping 5 times on Home header within 3s opens Demo screen', (
      tester,
    ) async {
      final fakeUserRepo = FakeUserRepository(
        meResponse: const MeResponse(
          id: 'u-1',
          displayName: 'Demo User',
          localDate: '2026-10-05',
        ),
      );

      final router = createAppRouter(initialLocation: '/home');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              FakeAuthRepository(
                initialUser: const AuthUser(
                  id: 'u-1',
                  email: 'demo@levelup.vn',
                ),
              ),
            ),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
            planRepositoryProvider.overrideWithValue(FakePlanRepository()),
            streakRepositoryProvider.overrideWithValue(FakeStreakRepository()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      final headerFinder = find.byKey(const ValueKey('home-header-title-tap'));
      expect(headerFinder, findsOneWidget);

      // Tap 5 times
      for (int i = 0; i < 5; i++) {
        await tester.tap(headerFinder);
        await tester.pump(const Duration(milliseconds: 100));
      }

      await tester.pumpAndSettle();

      // Should now be on DemoScreen
      expect(find.text('Giả lập Demo'), findsOneWidget);
      expect(find.text('Nạp dữ liệu demo'), findsOneWidget);
    });

    testWidgets('Action buttons call correct action on demo repository', (
      tester,
    ) async {
      final fakeDemoRepo = FakeDemoRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [demoRepositoryProvider.overrideWithValue(fakeDemoRepo)],
          child: const MaterialApp(home: DemoScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Seed action
      await tester.tap(find.text('Nạp dữ liệu demo'));
      await tester.pumpAndSettle();
      expect(fakeDemoRepo.lastActionCalled, 'seed');
      expect(find.byKey(const ValueKey('demo-result-text')), findsOneWidget);
      expect(
        find.textContaining('Đã nạp dữ liệu demo'),
        findsOneWidget,
      );

      // Skip-two action
      await tester.tap(find.text('Giả lập bỏ 2 buổi'));
      await tester.pumpAndSettle();
      expect(fakeDemoRepo.lastActionCalled, 'skip-two');
      expect(find.textContaining('Đã giả lập bỏ 2 buổi'), findsOneWidget);

      // Close-week action
      await tester.tap(find.text('Chốt tuần ngay'));
      await tester.pumpAndSettle();
      expect(fakeDemoRepo.lastActionCalled, 'close-week');
      expect(
        find.textContaining('Đã chốt tuần ngay thành công'),
        findsOneWidget,
      );

      // Review action
      await tester.tap(find.text('Tạo tổng kết tuần'));
      await tester.pumpAndSettle();
      expect(fakeDemoRepo.lastActionCalled, 'review');
      expect(
        find.textContaining('Đã tạo tổng kết tuần thành công'),
        findsOneWidget,
      );
    });

    testWidgets(
      '404 error displays "Tài khoản này chưa bật chế độ demo" without crash',
      (tester) async {
        final fakeDemoRepo = FakeDemoRepository(
          errorToThrow: const ApiException(code: 'NOT_FOUND', statusCode: 404),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [demoRepositoryProvider.overrideWithValue(fakeDemoRepo)],
            child: const MaterialApp(home: DemoScreen()),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Nạp dữ liệu demo'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('demo-result-text')), findsOneWidget);
        expect(find.text('Tài khoản này chưa bật chế độ demo'), findsOneWidget);
      },
    );

    testWidgets(
      'Notification test displays correct message for STORED_ONLY and SENT',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeDemoRepo = FakeDemoRepository(
          mockResult: {
            'action': 'checkin',
            'result': {'result': 'STORED_ONLY'},
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [demoRepositoryProvider.overrideWithValue(fakeDemoRepo)],
            child: const MaterialApp(home: DemoScreen()),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Gửi check-in sáng'));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('demo-result-text')), findsOneWidget);
        expect(
          find.text('Máy này chưa đăng ký nhận thông báo'),
          findsOneWidget,
        );

        // Now test SENT result
        fakeDemoRepo.mockResult = {
          'action': 'push-test',
          'result': {'result': 'SENT'},
        };

        await tester.tap(find.text('Gửi thông báo thử'));
        await tester.pumpAndSettle();

        expect(find.text('Đã gửi, xem thanh thông báo'), findsOneWidget);
      },
    );
  });
}
