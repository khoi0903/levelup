import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/push_notification_message.dart';

/// Kênh thông báo của app (tạo trong MainActivity với mức quan trọng cao để bật xuống từ đầu màn hình).
/// Đổi id khi cần đổi mức quan trọng: Android không cho sửa kênh đã tạo trên máy người dùng.
const String levelUpChannelId = 'levelup_alerts';
const String levelUpChannelName = 'Nhắc tập & thói quen';

/// Hiện thông báo lên thanh thông báo của điện thoại khi app ĐANG MỞ
/// (lúc đó Android không tự hiện thông báo FCM, chỉ chuyển cho app).
abstract class LocalNotifier {
  /// [onTap] nhận route trong payload khi người dùng bấm vào thông báo.
  Future<void> init({required void Function(String? route) onTap});

  Future<void> show(PushNotificationMessage message);
}

class FlutterLocalNotifier implements LocalNotifier {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  int _nextId = 0;

  @override
  Future<void> init({required void Function(String? route) onTap}) async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (response) => onTap(response.payload),
      );
    } catch (e) {
      debugPrint('FlutterLocalNotifier init error: $e');
    }
  }

  @override
  Future<void> show(PushNotificationMessage message) async {
    final title = message.title;
    final body = message.body;
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }
    try {
      await _plugin.show(
        id: _nextId++,
        title: title,
        body: body,
        payload: message.route,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            levelUpChannelId,
            levelUpChannelName,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('FlutterLocalNotifier show error: $e');
    }
  }
}

/// Dùng cho dev/web/test: ghi lại thông báo đã "hiện" để test kiểm tra.
class FakeLocalNotifier implements LocalNotifier {
  final List<PushNotificationMessage> shown = [];
  void Function(String? route)? _onTap;

  @override
  Future<void> init({required void Function(String? route) onTap}) async {
    _onTap = onTap;
  }

  @override
  Future<void> show(PushNotificationMessage message) async {
    shown.add(message);
  }

  /// Giả lập người dùng bấm vào thông báo.
  void tap(String? route) => _onTap?.call(route);
}
