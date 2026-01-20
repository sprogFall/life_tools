import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_notification_service.dart';
import 'notification_id_store.dart';

class LocalNotificationService implements AppNotificationService {
  static const String _channelId = 'app_messages';
  static const String _channelName = '应用消息';
  static const String _channelDescription = '来自应用内工具的消息通知';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  var _initialized = false;
  NotificationIdStore? _idStore;

  @override
  Future<void> init() async {
    if (_initialized) return;

    _idStore = await NotificationIdStore.open();

    tzdata.initializeTimeZones();
    try {
      final localName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localName));
    } catch (e) {
      debugPrint('初始化时区失败，将使用 UTC: $e');
    }

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

  NotificationDetails _details() {
    return NotificationDetails(
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
  }

  @override
  Future<void> showMessage({
    required String title,
    required String body,
  }) async {
    if (!_initialized) {
      await init();
    }

    try {
      final id = await _idStore!.reserve();
      await _plugin.show(id, title, body, _details());
    } catch (e) {
      debugPrint('本地通知发送失败: $e');
    }
  }

  @override
  Future<void> scheduleMessage({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    if (!_initialized) {
      await init();
    }

    final now = DateTime.now();
    if (!scheduledAt.isAfter(now)) return;

    final scheduled = tz.TZDateTime.from(scheduledAt, tz.local);

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _details(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: null,
      );
    } catch (e) {
      debugPrint('本地通知定时发送失败: $e');
    }
  }

  @override
  Future<void> cancel(int id) async {
    if (!_initialized) {
      await init();
    }
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('本地通知取消失败: $e');
    }
  }
}
