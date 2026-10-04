import 'dart:async';

import '../../domain/models/push_notification_message.dart';
import '../../domain/services/push_service.dart';

/// Dịch vụ push giả lập dùng cho chế độ dev (AUTH_MODE=dev), web và automated tests.
class FakePushService implements PushService {
  bool permissionGranted;
  String? mockToken;
  bool deleteTokenCalled = false;
  bool requestPermissionCalled = false;
  int deleteTokenCallCount = 0;

  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();
  final StreamController<PushNotificationMessage> _messageController =
      StreamController<PushNotificationMessage>.broadcast();
  final StreamController<PushNotificationMessage> _messageOpenedAppController =
      StreamController<PushNotificationMessage>.broadcast();
  PushNotificationMessage? initialMessage;

  FakePushService({
    this.permissionGranted = true,
    this.mockToken = 'fake-fcm-token',
    this.initialMessage,
  });

  @override
  Future<bool> requestPermission() async {
    requestPermissionCalled = true;
    return permissionGranted;
  }

  @override
  Future<bool> hasPermission() async {
    return permissionGranted;
  }

  @override
  Future<String?> getToken() async {
    return mockToken;
  }

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  Future<void> deleteToken() async {
    deleteTokenCalled = true;
    deleteTokenCallCount++;
    mockToken = null;
  }

  @override
  Stream<PushNotificationMessage> get onMessage => _messageController.stream;

  @override
  Stream<PushNotificationMessage> get onMessageOpenedApp =>
      _messageOpenedAppController.stream;

  @override
  Future<PushNotificationMessage?> getInitialMessage() async {
    return initialMessage;
  }

  // --- Các hàm hỗ trợ kiểm thử ---

  void emitTokenRefresh(String token) {
    mockToken = token;
    _tokenRefreshController.add(token);
  }

  void emitForegroundMessage(PushNotificationMessage message) {
    _messageController.add(message);
  }

  void emitMessageOpenedApp(PushNotificationMessage message) {
    _messageOpenedAppController.add(message);
  }

  void setInitialMessage(PushNotificationMessage? message) {
    initialMessage = message;
  }

  void dispose() {
    _tokenRefreshController.close();
    _messageController.close();
    _messageOpenedAppController.close();
  }
}
