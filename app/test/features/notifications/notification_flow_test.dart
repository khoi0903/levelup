import 'package:fitness_app/features/auth/data/repositories/fake_auth_repository.dart';
import 'package:fitness_app/features/auth/domain/models/auth_user.dart';
import 'package:fitness_app/features/auth/presentation/controllers/auth_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:fitness_app/features/notifications/data/repositories/fake_device_repository.dart';
import 'package:fitness_app/features/notifications/data/services/fake_push_service.dart';
import 'package:fitness_app/features/notifications/domain/models/notification_route_mapper.dart';
import 'package:fitness_app/features/notifications/domain/models/push_notification_message.dart';
import 'package:fitness_app/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_notify_screen.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:fitness_app/features/users/presentation/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('1. Map route -> đường dẫn go_router', () {
    test('/checkin -> /checkin', () {
      expect(mapNotificationRoute('/checkin'), equals('/checkin'));
    });

    test('/workout/<sessionId> -> /workout/<sessionId>', () {
      expect(
        mapNotificationRoute('/workout/session-abc-123'),
        equals('/workout/session-abc-123'),
      );
      expect(mapNotificationRoute('/workout'), equals('/workout'));
    });

    test('/nutrition -> /nutrition', () {
      expect(mapNotificationRoute('/nutrition'), equals('/nutrition'));
      expect(
        mapNotificationRoute('/nutrition?tab=water'),
        equals('/nutrition'),
      );
    });

    test('/coach (+ coachMessageId) -> /coach', () {
      expect(mapNotificationRoute('/coach'), equals('/coach'));
      expect(
        mapNotificationRoute('/coach?coachMessageId=msg-99'),
        equals('/coach'),
      );
      expect(mapNotificationRoute('/coach/msg-99'), equals('/coach'));
    });

    test('/buddy (+ pairId) -> /buddy', () {
      expect(mapNotificationRoute('/buddy'), equals('/buddy'));
      expect(mapNotificationRoute('/buddy?pairId=pair-01'), equals('/buddy'));
      expect(mapNotificationRoute('/buddy/pair-01'), equals('/buddy'));
    });

    test('/review (+ reviewId) -> /reviews/latest', () {
      expect(mapNotificationRoute('/review'), equals('/reviews/latest'));
      expect(
        mapNotificationRoute('/review?reviewId=rev-5'),
        equals('/reviews/latest'),
      );
      expect(mapNotificationRoute('/review/rev-5'), equals('/reviews/latest'));
    });

    test('/plan -> /workout', () {
      expect(mapNotificationRoute('/plan'), equals('/workout'));
      expect(mapNotificationRoute('/plan?week=1'), equals('/workout'));
    });

    test('route lạ / thiếu -> /home', () {
      expect(mapNotificationRoute(null), equals('/home'));
      expect(mapNotificationRoute(''), equals('/home'));
      expect(mapNotificationRoute('   '), equals('/home'));
      expect(mapNotificationRoute('/unknown-path'), equals('/home'));
      expect(mapNotificationRoute('random_string'), equals('/home'));
      expect(mapNotificationRoute('/setting'), equals('/home'));
    });
  });

  group('2. Đăng ký FCM token khi GET /me', () {
    test('Sau GET /me thành công với FakePushService có token -> DeviceRepository nhận đúng {token, platform}', () async {
      final fakePush = FakePushService(
        permissionGranted: true,
        mockToken: 'sample-token-fcm-456',
      );
      final fakeDeviceRepo = FakeDeviceRepository();
      final fakeUserRepo = FakeUserRepository(
        meResponse: const MeResponse(
          id: 'user-001',
          displayName: 'Test User',
          settings: UserSettings(
            notifications: UserNotificationsSettings(pushEnabled: true),
          ),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          pushServiceProvider.overrideWithValue(fakePush),
          deviceRepositoryProvider.overrideWithValue(fakeDeviceRepo),
          userRepositoryProvider.overrideWithValue(fakeUserRepo),
        ],
      );
      addTearDown(container.dispose);

      // Gọi GET /me
      final me = await container.read(userStatusFutureProvider.future);
      expect(me.id, equals('user-001'));

      // Đợi microtasks / async calls hoàn tất
      await Future<void>.delayed(Duration.zero);

      expect(fakeDeviceRepo.registerCalled, isTrue);
      expect(fakeDeviceRepo.registeredDevices.length, equals(1));
      expect(
        fakeDeviceRepo.registeredDevices.first.token,
        equals('sample-token-fcm-456'),
      );
      expect([
        'android',
        'ios',
        'web',
      ], contains(fakeDeviceRepo.registeredDevices.first.platform));
    });

    test('pushEnabled = false -> không gọi POST /devices', () async {
      final fakePush = FakePushService(
        permissionGranted: true,
        mockToken: 'sample-token-fcm-456',
      );
      final fakeDeviceRepo = FakeDeviceRepository();
      final fakeUserRepo = FakeUserRepository(
        meResponse: const MeResponse(
          id: 'user-002',
          displayName: 'Test User Disabled',
          settings: UserSettings(
            notifications: UserNotificationsSettings(pushEnabled: false),
          ),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          pushServiceProvider.overrideWithValue(fakePush),
          deviceRepositoryProvider.overrideWithValue(fakeDeviceRepo),
          userRepositoryProvider.overrideWithValue(fakeUserRepo),
        ],
      );
      addTearDown(container.dispose);

      final me = await container.read(userStatusFutureProvider.future);
      expect(me.settings.notifications.pushEnabled, isFalse);

      await Future<void>.delayed(Duration.zero);

      expect(fakeDeviceRepo.registerCalled, isFalse);
      expect(fakeDeviceRepo.registeredDevices, isEmpty);
    });

    test(
      'từ chối quyền (permissionGranted = false) -> không gọi POST /devices',
      () async {
        final fakePush = FakePushService(
          permissionGranted: false, // Từ chối quyền
          mockToken: 'sample-token-fcm-456',
        );
        final fakeDeviceRepo = FakeDeviceRepository();
        final fakeUserRepo = FakeUserRepository(
          meResponse: const MeResponse(
            id: 'user-003',
            displayName: 'Test User Denied',
            settings: UserSettings(
              notifications: UserNotificationsSettings(pushEnabled: true),
            ),
          ),
        );

        final container = ProviderContainer(
          overrides: [
            pushServiceProvider.overrideWithValue(fakePush),
            deviceRepositoryProvider.overrideWithValue(fakeDeviceRepo),
            userRepositoryProvider.overrideWithValue(fakeUserRepo),
          ],
        );
        addTearDown(container.dispose);

        await container.read(userStatusFutureProvider.future);
        await Future<void>.delayed(Duration.zero);

        expect(fakeDeviceRepo.registerCalled, isFalse);
        expect(fakeDeviceRepo.registeredDevices, isEmpty);
      },
    );
  });

  group('3. Đăng xuất gọi deleteToken', () {
    test(
      'SettingsNotifier.logout() gọi deleteToken trước khi signOut',
      () async {
        final fakePush = FakePushService(
          permissionGranted: true,
          mockToken: 'sample-token',
        );
        final fakeAuth = FakeAuthRepository(
          initialUser: const AuthUser(
            id: 'user-logout-test',
            email: 'test@levelup.vn',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            pushServiceProvider.overrideWithValue(fakePush),
            authRepositoryProvider.overrideWithValue(fakeAuth),
          ],
        );
        addTearDown(container.dispose);

        expect(fakePush.deleteTokenCalled, isFalse);
        expect(fakeAuth.signOutCalled, isFalse);

        await container.read(settingsControllerProvider.notifier).logout();

        expect(fakePush.deleteTokenCalled, isTrue);
        expect(fakePush.deleteTokenCallCount, equals(1));
        expect(fakeAuth.signOutCalled, isTrue);
      },
    );

    test(
      'AuthNotifier.signOut() gọi deleteToken trước khi repository.signOut',
      () async {
        final fakePush = FakePushService(
          permissionGranted: true,
          mockToken: 'sample-token',
        );
        final fakeAuth = FakeAuthRepository(
          initialUser: const AuthUser(
            id: 'user-logout-test-2',
            email: 'test2@levelup.vn',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            pushServiceProvider.overrideWithValue(fakePush),
            authRepositoryProvider.overrideWithValue(fakeAuth),
          ],
        );
        addTearDown(container.dispose);

        expect(fakePush.deleteTokenCalled, isFalse);

        await container.read(authControllerProvider.notifier).signOut();

        expect(fakePush.deleteTokenCalled, isTrue);
        expect(fakeAuth.signOutCalled, isTrue);
      },
    );
  });

  group('4. Onboarding ob_notify_screen xin quyền và setPushEnabled', () {
    testWidgets(
      'Bật thông báo -> xin quyền hệ thống thành công -> setPushEnabled(true)',
      (tester) async {
        final fakePush = FakePushService(permissionGranted: true);
        final router = GoRouter(
          initialLocation: '/onboarding/notify',
          routes: [
            GoRoute(
              path: '/onboarding/notify',
              builder: (context, state) => const ObNotifyScreen(),
            ),
            GoRoute(
              path: '/onboarding/start',
              builder: (context, state) => const SizedBox(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [pushServiceProvider.overrideWithValue(fakePush)],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        final enableBtn = find.text('Bật thông báo');
        expect(enableBtn, findsOneWidget);

        await tester.tap(enableBtn);
        await tester.pumpAndSettle();

        expect(fakePush.requestPermissionCalled, isTrue);
      },
    );

    testWidgets(
      'Bật thông báo -> người dùng từ chối quyền -> setPushEnabled(false) và không crash',
      (tester) async {
        final fakePush = FakePushService(permissionGranted: false);
        final router = GoRouter(
          initialLocation: '/onboarding/notify',
          routes: [
            GoRoute(
              path: '/onboarding/notify',
              builder: (context, state) => const ObNotifyScreen(),
            ),
            GoRoute(
              path: '/onboarding/start',
              builder: (context, state) => const SizedBox(),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [pushServiceProvider.overrideWithValue(fakePush)],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        final enableBtn = find.text('Bật thông báo');
        await tester.tap(enableBtn);
        await tester.pumpAndSettle();

        expect(fakePush.requestPermissionCalled, isTrue);
      },
    );
  });

  group('5. Cài đặt profile_screen xin quyền khi bật lại thông báo', () {
    testWidgets(
      'Bật lại khi chưa có quyền và bị từ chối -> hiện SnackBar hướng dẫn',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakePush = FakePushService(permissionGranted: false);
        final fakeUserRepo = FakeUserRepository(
          meResponse: const MeResponse(
            id: 'u-settings',
            displayName: 'User Settings',
            settings: UserSettings(
              notifications: UserNotificationsSettings(pushEnabled: false),
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              pushServiceProvider.overrideWithValue(fakePush),
              userRepositoryProvider.overrideWithValue(fakeUserRepo),
            ],
            child: const MaterialApp(home: ProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final titleFinder = find.text('Bật thông báo nhắc tập');
        expect(titleFinder, findsOneWidget);

        // Tìm switch đầu tiên trong phần thông báo
        final switchFinder = find.byType(Switch).first;
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        // Phải gọi requestPermission và hiện SnackBar hướng dẫn
        expect(fakePush.requestPermissionCalled, isTrue);
        expect(
          find.text(
            'Vui lòng mở Cài đặt điện thoại để cho phép LevelUp gửi thông báo.',
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('6. Foreground notification banner', () {
    testWidgets('showForegroundNotificationBanner hiển thị title và body', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          home: const Scaffold(body: Center(child: Text('Trang chính'))),
        ),
      );
      await tester.pumpAndSettle();

      showForegroundNotificationBanner(
        const PushNotificationMessage(
          title: 'Nhắc nhở tập luyện',
          body: 'Đã đến giờ tập 15 phút hôm nay rồi!',
          data: {'route': '/workout'},
        ),
      );
      await tester.pump();

      expect(find.text('Nhắc nhở tập luyện'), findsOneWidget);
      expect(find.text('Đã đến giờ tập 15 phút hôm nay rồi!'), findsOneWidget);
      expect(find.text('Xem'), findsOneWidget);
    });
  });
}
