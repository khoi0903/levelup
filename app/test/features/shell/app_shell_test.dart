import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/core/utils/error_messages.dart';
import 'package:fitness_app/core/widgets/empty_view.dart';
import 'package:fitness_app/core/widgets/error_view.dart';
import 'package:fitness_app/core/widgets/offline_banner.dart';
import 'package:fitness_app/features/coach/data/repositories/fake_coach_repository.dart';
import 'package:fitness_app/features/coach/presentation/controllers/coach_controller.dart';
import 'package:fitness_app/features/nutrition/data/repositories/fake_nutrition_repository.dart';
import 'package:fitness_app/features/nutrition/presentation/controllers/nutrition_controller.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_plan_repository.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:fitness_app/features/streak/data/repositories/fake_streak_repository.dart';
import 'package:fitness_app/features/streak/presentation/controllers/streak_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppShell and Navigation', () {
    testWidgets('5 tabs navigation switches content correctly', (tester) async {
      final fakeUserRepo = FakeUserRepository(
        meResponse: const MeResponse(
          id: 'user-1',
          displayName: 'Anh Khoi',
          streak: UserStreak(currentWeeks: 3, bestWeeks: 6, freezesAvailable: 2),
        ),
      );

      final fakeStreakRepo = FakeStreakRepository();
      final fakePlanRepo = FakePlanRepository();
      final fakeCoachRepo = FakeCoachRepository();

      final router = createAppRouter(initialLocation: '/home');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
            planRepositoryProvider.overrideWithValue(fakePlanRepo),
            streakRepositoryProvider.overrideWithValue(fakeStreakRepo),
            coachRepositoryProvider.overrideWithValue(fakeCoachRepo),
            nutritionRepositoryProvider.overrideWithValue(FakeNutritionRepository()),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Starts at Home tab
      expect(find.byKey(const ValueKey('tab-home')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-workout')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-coach')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-nutrition')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab-profile')), findsOneWidget);

      // Tap Coach tab
      await tester.tap(find.byKey(const ValueKey('tab-coach')));
      await tester.pumpAndSettle();
      expect(find.text('AI Coach'), findsOneWidget);

      // Tap Dinh dưỡng tab
      await tester.tap(find.byKey(const ValueKey('tab-nutrition')));
      await tester.pumpAndSettle();
      // Tab Dinh dưỡng mở màn thật (tiêu đề + nhãn tab cùng chữ)
      expect(find.text('Thêm món thủ công'), findsOneWidget);

      // Tap Tôi tab (Profile)
      await tester.tap(find.byKey(const ValueKey('tab-profile')));
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ & Cài đặt'), findsOneWidget);
      expect(find.text('Anh Khoi'), findsWidgets);

      // Tap Trang chủ tab
      await tester.tap(find.byKey(const ValueKey('tab-home')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-greeting-text')), findsOneWidget);
      expect(find.textContaining('Anh Khoi'), findsWidgets);
    });

    testWidgets('Router errorBuilder displays 404 page for unknown route', (tester) async {
      final router = createAppRouter(initialLocation: '/non-existent-route-xyz');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Không tìm thấy trang (404)'), findsOneWidget);
      expect(find.text('Về trang chủ'), findsOneWidget);
    });
  });

  group('Common Widgets & Error Mapping', () {
    testWidgets('ErrorView renders error message and triggers onRetry', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorView(
              code: 'COACH_LIMIT',
              message: 'Đã hết lượt nhắn tin với Coach',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Có lỗi xảy ra (COACH_LIMIT)'), findsOneWidget);
      expect(find.text('Đã hết lượt nhắn tin với Coach'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);

      await tester.tap(find.text('Thử lại'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('EmptyView renders icon and title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyView(
              title: 'Không có dữ liệu',
              subtitle: 'Hãy thử tải lại sau nhé',
              icon: Icons.inbox,
            ),
          ),
        ),
      );

      expect(find.text('Không có dữ liệu'), findsOneWidget);
      expect(find.text('Hãy thử tải lại sau nhé'), findsOneWidget);
      expect(find.byIcon(Icons.inbox), findsOneWidget);
    });

    testWidgets('OfflineBanner renders message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              message: 'Đang ngoại tuyến',
            ),
          ),
        ),
      );

      expect(find.text('Đang ngoại tuyến'), findsOneWidget);
    });

    test('mapErrorMessage maps known and unknown error codes properly', () {
      expect(
        mapErrorMessage(const ApiException(code: 'ONBOARDING_REQUIRED')),
        'Bạn cần hoàn thành bảng khảo sát ban đầu trước khi tiếp tục.',
      );
      expect(
        mapErrorMessage(const ApiException(code: 'COACH_LIMIT')),
        'Hôm nay bạn đã dùng hết lượt nhắn tin với Coach. Hãy quay lại vào ngày mai nhé!',
      );
      expect(
        mapErrorMessage(const ApiException(code: 'PHOTO_LIMIT_REACHED')),
        'Đã đạt giới hạn nhận diện ảnh món ăn trong ngày.',
      );
      expect(
        mapErrorMessage(const ApiException(code: 'NETWORK_ERROR')),
        'Không kết nối được máy chủ. Vui lòng kiểm tra kết nối mạng.',
      );
      expect(
        mapErrorMessage(const ApiException(code: 'HTTP_401', statusCode: 401)),
        'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
      expect(
        mapErrorMessage(const ApiException(code: 'HTTP_429', statusCode: 429)),
        'Hệ thống đang quá tải hoặc bạn đã vượt quá giới hạn yêu cầu.',
      );
      expect(
        mapErrorMessage(const ApiException(code: 'HTTP_500', statusCode: 500)),
        'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.',
      );
      expect(
        mapErrorMessage(const ApiException(code: 'UNKNOWN_CODE_XYZ')),
        'Đã có lỗi xảy ra (UNKNOWN_CODE_XYZ). Vui lòng thử lại.',
      );
    });
  });
}
