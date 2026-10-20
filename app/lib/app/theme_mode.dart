import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chế độ giao diện (Theo hệ thống / Sáng / Tối), lưu trên máy.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier([super.initial = ThemeMode.system]);

  static const prefKey = 'app_theme_mode';

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      await (await SharedPreferences.getInstance()).setString(prefKey, mode.name);
    } catch (_) {}
  }
}

/// Đọc chế độ đã lưu trước khi chạy app để màn đầu không bị nháy sáng→tối.
Future<ThemeMode> loadSavedThemeMode() async {
  try {
    final saved = (await SharedPreferences.getInstance())
        .getString(ThemeModeNotifier.prefKey);
    return ThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => ThemeMode.system,
    );
  } catch (_) {
    return ThemeMode.system;
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);
