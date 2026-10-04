import '../models/push_notification_message.dart';

/// Giao diện dịch vụ thông báo đẩy (FCM hoặc giả lập).
abstract class PushService {
  /// Yêu cầu người dùng cấp quyền thông báo từ hệ điều hành.
  /// Trả về true nếu đã được cấp quyền, false nếu bị từ chối.
  Future<bool> requestPermission();

  /// Kiểm tra xem hiện tại đã có quyền thông báo hay chưa mà không hiện hộp thoại hỏi lại.
  Future<bool> hasPermission();

  /// Lấy FCM registration token của thiết bị.
  Future<String?> getToken();

  /// Luồng phát ra token mới mỗi khi FCM làm mới token.
  Stream<String> get onTokenRefresh;

  /// Xóa token đăng ký trên thiết bị khi người dùng đăng xuất.
  Future<void> deleteToken();

  /// Luồng thông báo nhận được khi ứng dụng đang mở (foreground).
  Stream<PushNotificationMessage> get onMessage;

  /// Luồng thông báo khi người dùng nhấn vào thông báo (ứng dụng ở chế độ nền).
  Stream<PushNotificationMessage> get onMessageOpenedApp;

  /// Lấy thông báo đã mở ứng dụng khi ứng dụng bị tắt hoàn toàn (terminated).
  Future<PushNotificationMessage?> getInitialMessage();
}
