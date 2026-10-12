import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Extension hỗ trợ lưu cache trong bộ nhớ cho Riverpod provider.
///
/// Hoạt động theo cơ chế keepAlive() kết hợp với Timer hủy sau thời hạn.
/// Khi provider bị invalidate hoặc dispose trước thời hạn, timer tự hủy.
extension CacheForExtension on Ref {
  static bool enableTimer = () {
    try {
      return Platform.environment['FLUTTER_TEST'] != 'true';
    } catch (_) {
      return true;
    }
  }();

  void cacheFor(Duration duration) {
    final link = keepAlive();
    if (!enableTimer) return;
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}
