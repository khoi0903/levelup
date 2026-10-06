import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Tự mở camera khi bắt đầu hiệp": bài có đếm bằng camera thì vào hiệp là mở màn camera luôn,
/// không phải bấm "Đếm bằng camera". Mặc định bật, lưu trên máy.
class AutoCameraNotifier extends StateNotifier<bool> {
  AutoCameraNotifier() : super(true) {
    _load();
  }

  static const _key = 'auto_camera_on_set_start';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_key);
      if (saved != null && mounted) state = saved;
    } catch (_) {
      // Không đọc được thì giữ mặc định bật
    }
  }

  Future<void> set(bool value) async {
    state = value;
    try {
      await (await SharedPreferences.getInstance()).setBool(_key, value);
    } catch (_) {}
  }
}

final autoCameraProvider =
    StateNotifierProvider<AutoCameraNotifier, bool>((ref) => AutoCameraNotifier());
