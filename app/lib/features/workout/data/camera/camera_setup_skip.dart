import 'package:shared_preferences/shared_preferences.dart';

/// Nhớ ngày người dùng chọn "Không hỏi lại hôm nay" ở màn Đặt camera.
/// Sang ngày khác thì màn hướng dẫn hiện lại một lần. Test ghi đè bằng [MemoryCameraSetupSkip].
abstract class CameraSetupSkip {
  /// Ngày đã chọn bỏ qua, dạng "YYYY-MM-DD", hoặc null.
  Future<String?> skippedDate();

  Future<void> skipFor(String localDate);
}

class PrefsCameraSetupSkip implements CameraSetupSkip {
  const PrefsCameraSetupSkip();

  static const _key = 'camera_setup_skipped_date';

  @override
  Future<String?> skippedDate() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_key);
    } catch (_) {
      return null; // Không đọc được thì cứ hiện hướng dẫn, không chặn người dùng
    }
  }

  @override
  Future<void> skipFor(String localDate) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_key, localDate);
    } catch (_) {
      // Lưu không được thì lần sau hỏi lại, không sao
    }
  }
}

class MemoryCameraSetupSkip implements CameraSetupSkip {
  MemoryCameraSetupSkip([this._date]);

  String? _date;

  @override
  Future<String?> skippedDate() async => _date;

  @override
  Future<void> skipFor(String localDate) async => _date = localDate;
}
