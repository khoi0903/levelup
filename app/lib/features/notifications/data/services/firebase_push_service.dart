import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/push_notification_message.dart';
import '../../domain/services/push_service.dart';

class FirebasePushService implements PushService {
  final FirebaseMessaging? _customFcm;

  FirebasePushService([FirebaseMessaging? fcm]) : _customFcm = fcm;

  FirebaseMessaging get _fcm => _customFcm ?? FirebaseMessaging.instance;

  @override
  Future<bool> requestPermission() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('FirebasePushService requestPermission error: $e');
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      final settings = await _fcm.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('FirebasePushService hasPermission error: $e');
      return false;
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('FirebasePushService getToken error: $e');
      return null;
    }
  }

  @override
  Stream<String> get onTokenRefresh => _fcm.onTokenRefresh;

  @override
  Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('FirebasePushService deleteToken error: $e');
    }
  }

  @override
  Stream<PushNotificationMessage> get onMessage => FirebaseMessaging.onMessage
      .map(PushNotificationMessage.fromRemoteMessage);

  @override
  Stream<PushNotificationMessage> get onMessageOpenedApp => FirebaseMessaging
      .onMessageOpenedApp
      .map(PushNotificationMessage.fromRemoteMessage);

  @override
  Future<PushNotificationMessage?> getInitialMessage() async {
    try {
      final remoteMessage = await _fcm.getInitialMessage();
      if (remoteMessage != null) {
        return PushNotificationMessage.fromRemoteMessage(remoteMessage);
      }
    } catch (e) {
      debugPrint('FirebasePushService getInitialMessage error: $e');
    }
    return null;
  }
}
