import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

enum CameraPermissionResult { granted, denied, permanentlyDenied }

/// Xin quyền camera trước khi mở màn đếm. Test ghi đè bằng bản giả.
abstract class CameraPermissionGate {
  Future<CameraPermissionResult> request();
  Future<void> openSettings();
}

class PlatformCameraPermissionGate implements CameraPermissionGate {
  const PlatformCameraPermissionGate();

  @override
  Future<CameraPermissionResult> request() async {
    // iOS: plugin camera tự hỏi quyền theo NSCameraUsageDescription khi mở,
    // giống camera_rep_device.dart (tránh cần macro Podfile của permission_handler).
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return CameraPermissionResult.granted;
    }
    final status = await Permission.camera.request();
    if (status.isGranted) return CameraPermissionResult.granted;
    return status.isPermanentlyDenied
        ? CameraPermissionResult.permanentlyDenied
        : CameraPermissionResult.denied;
  }

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
