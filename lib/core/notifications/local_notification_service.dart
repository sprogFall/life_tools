import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_notification_service.dart';

class LocalNotificationService implements AppNotificationService {
  static const String _channelId = 'app_messages';
  static const String _channelName = '应用消息';
  static const String _channelDescription = '来自应用内工具的消息通知';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  var _initialized = false;
  var _nextId = 1;

  @override
  Future<void> init() async {
    if (_initialized) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const settings = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(settings);

    if (Platform.isAndroid) {
      final androidImpl =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
          >();
      await androidImpl?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.high,
        ),
      );
      await androidImpl?.requestNotificationsPermission();
    }

    if (Platform.isIOS || Platform.isMacOS) {
      final iosImpl =
          _plugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
          >();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _initialized = true;
  }

  @override
  Future<void> showMessage({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await init();
    }

    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
    );

    try {
      await _plugin.show(_nextId++, title, body, details);
    } catch (e) {
      debugPrint('本地通知发送失败: $e');
    }
  }
}
