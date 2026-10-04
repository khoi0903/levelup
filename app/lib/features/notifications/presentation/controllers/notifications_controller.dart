import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/auth_constants.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../data/repositories/api_device_repository.dart';
import '../../data/services/fake_push_service.dart';
import '../../data/services/firebase_push_service.dart';
import '../../domain/models/notification_route_mapper.dart';
import '../../domain/models/push_notification_message.dart';
import '../../domain/repositories/device_repository.dart';
import '../../domain/services/push_service.dart';

/// Global Key để hiển thị SnackBar / Banner thông báo ở bất kỳ đâu trong app.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Xác định nền tảng thiết bị theo chuẩn backend ('android' | 'ios' | 'web').
String getDevicePlatform() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
    default:
      return 'android';
  }
}

/// Provider cung cấp dịch vụ push notification.
/// Chế độ AUTH_MODE=dev, web hoặc khi Firebase chưa khởi tạo (automated tests): tự động dùng FakePushService để không crash.
final pushServiceProvider = Provider<PushService>((ref) {
  if (kIsWeb || AuthConstants.isDevMode || Firebase.apps.isEmpty) {
    return FakePushService();
  }
  return FirebasePushService();
});

/// Provider cung cấp DeviceRepository gọi POST /devices.
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiDeviceRepository(client);
});

/// Lưu route chờ điều hướng từ initialMessage (khi app mở từ trạng thái bị tắt).
final pendingNotificationRouteProvider = StateProvider<String?>((ref) => null);

/// Điều phối nhận, điều hướng và đăng ký token thông báo.
class NotificationCoordinator {
  final Ref _ref;
  final PushService _pushService;

  /// Lấy lúc cần (không dựng sẵn): ApiClient kéo theo token đăng nhập, chưa cần khi chưa có quyền thông báo.
  DeviceRepository get _deviceRepository => _ref.read(deviceRepositoryProvider);

  StreamSubscription<PushNotificationMessage>? _messageSubscription;
  StreamSubscription<PushNotificationMessage>? _messageOpenedSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;

  NotificationCoordinator(this._ref, this._pushService);

  /// Khởi tạo các bộ lắng nghe sự kiện push notification.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // 1. App đang mở (foreground): hiển thị SnackBar/Banner trong app
    _messageSubscription = _pushService.onMessage.listen((message) {
      showForegroundNotificationBanner(message);
    });

    // 2. App chạy nền (background): người dùng nhấn vào thông báo hệ thống
    _messageOpenedSubscription = _pushService.onMessageOpenedApp.listen((
      message,
    ) {
      final targetRoute = mapNotificationRoute(message.route);
      appRouter.go(targetRoute);
    });

    // 3. Token thay đổi: gửi lại POST /devices nếu người dùng đã đăng nhập & bật push
    _tokenRefreshSubscription = _pushService.onTokenRefresh.listen((
      newToken,
    ) async {
      final currentUser = _ref.read(currentUserProvider);
      if (currentUser != null &&
          currentUser.settings.notifications.pushEnabled) {
        try {
          await _deviceRepository.registerDevice(
            token: newToken,
            platform: getDevicePlatform(),
          );
        } catch (e) {
          debugPrint('NotificationCoordinator onTokenRefresh error: $e');
        }
      }
    });

    // 4. App đã tắt (terminated): getInitialMessage
    try {
      final initialMessage = await _pushService.getInitialMessage();
      if (initialMessage != null) {
        final targetRoute = mapNotificationRoute(initialMessage.route);
        final currentUser = _ref.read(currentUserProvider);
        if (currentUser != null) {
          // Người dùng đã sẵn sàng trong app -> điều hướng luôn
          appRouter.go(targetRoute);
        } else {
          // Lưu lại để BootstrapScreen điều hướng sau khi đăng nhập và GET /me thành công
          _ref.read(pendingNotificationRouteProvider.notifier).state =
              targetRoute;
        }
      }
    } catch (e) {
      debugPrint('NotificationCoordinator getInitialMessage error: $e');
    }
  }

  /// Đăng ký FCM token lên backend nếu người dùng cho phép và đã cấp quyền hệ thống.
  Future<void> registerDeviceTokenIfEligible() async {
    try {
      final hasPermission = await _pushService.hasPermission();
      if (!hasPermission) {
        return;
      }

      final token = await _pushService.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      await _deviceRepository.registerDevice(
        token: token,
        platform: getDevicePlatform(),
      );
    } catch (e) {
      // Lỗi mạng hoặc 401: chỉ debugPrint, không hiện lỗi cho người dùng, không chặn luồng
      debugPrint('NotificationCoordinator registerDeviceToken error: $e');
    }
  }

  void dispose() {
    _messageSubscription?.cancel();
    _messageOpenedSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
  }
}

final notificationCoordinatorProvider = Provider<NotificationCoordinator>((
  ref,
) {
  final pushService = ref.watch(pushServiceProvider);
  final coordinator = NotificationCoordinator(ref, pushService);
  ref.onDispose(() => coordinator.dispose());
  return coordinator;
});

/// Hiển thị banner/SnackBar nhỏ trong app khi nhận thông báo ở chế độ foreground (mục 5).
void showForegroundNotificationBanner(PushNotificationMessage message) {
  final messenger = rootScaffoldMessengerKey.currentState;
  if (messenger == null) return;

  final title = message.title;
  final body = message.body;
  if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
    return;
  }

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: const Color(0xFF1E293B), // slate-800 đậm rõ nét
      duration: const Duration(seconds: 4),
      content: InkWell(
        onTap: () {
          messenger.hideCurrentSnackBar();
          final path = mapNotificationRoute(message.route);
          appRouter.go(path);
        },
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title != null && title.isNotEmpty)
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (body != null && body.isNotEmpty)
                    Text(
                      body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      action: SnackBarAction(
        label: 'Xem',
        textColor: AppColors.accent,
        onPressed: () {
          final path = mapNotificationRoute(message.route);
          appRouter.go(path);
        },
      ),
    ),
  );
}
