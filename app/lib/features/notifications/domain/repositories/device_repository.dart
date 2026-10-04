/// Quản lý việc đăng ký thiết bị nhận thông báo với backend LevelUp.
abstract class DeviceRepository {
  /// Đăng ký FCM token lên backend: POST /devices
  /// [platform] phải là 'android' | 'ios' | 'web'.
  Future<void> registerDevice({
    required String token,
    required String platform,
  });
}
