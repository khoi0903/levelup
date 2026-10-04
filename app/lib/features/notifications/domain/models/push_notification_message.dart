import 'package:firebase_messaging/firebase_messaging.dart';

/// Đại diện cho một thông báo đẩy nhận được từ FCM hoặc giả lập.
class PushNotificationMessage {
  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  const PushNotificationMessage({this.title, this.body, this.data = const {}});

  /// Lấy route điều hướng từ payload `data['route']`.
  String? get route {
    final r = data['route'];
    return r is String ? r : null;
  }

  factory PushNotificationMessage.fromRemoteMessage(RemoteMessage message) {
    return PushNotificationMessage(
      title: message.notification?.title ?? message.data['title']?.toString(),
      body: message.notification?.body ?? message.data['body']?.toString(),
      data: message.data,
    );
  }
}
