import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<String?>.broadcast();

  /// Payloads of tapped local notifications, from every app state.
  Stream<String?> get onTap => _taps.stream;

  // A heads-up banner on Android needs a high-importance channel.
  static const _channel = AndroidNotificationChannel(
    'updates',
    'Updates',
    description: 'Live shows, schedule changes and new articles.',
    importance: Importance.high,
  );

  Future<void> init() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) =>
          _taps.add(response.payload),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    await _handleLaunchPayload();
    await _setUpForegroundPushes();
  }

  Future<void> requestPermission() async {
    await FirebaseMessaging.instance.requestPermission();
  }

  // A local notification tapped while the app was dead never reaches
  // onDidReceiveNotificationResponse, so we pick it up here instead.
  Future<void> _handleLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    final payload = details?.notificationResponse?.payload;
    if (details?.didNotificationLaunchApp != true || payload == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) => _taps.add(payload));
  }

  // FCM never shows a push while the app is open. iOS can show it natively
  // (the tap then arrives through onMessageOpenedApp), but on Android we
  // have to show it ourselves as a local notification.
  Future<void> _setUpForegroundPushes() async {
    if (Platform.isIOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      return;
    }

    FirebaseMessaging.onMessage.listen(_showForegroundPush);
  }

  Future<void> _showForegroundPush(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _plugin.show(
      // Android notification ids must fit in a 32-bit int.
      id: message.messageId.hashCode & 0x7fffffff,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}
