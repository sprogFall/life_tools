import 'package:flutter/foundation.dart';

import '../notifications/app_notification_service.dart';
import 'message_repository.dart';
import 'models/app_message.dart';

class MessageService extends ChangeNotifier {
  static const defaultExpiresIn = Duration(days: 1);

  final MessageRepository _repository;
  final AppNotificationService? _notificationService;
  final int _maxMessages;

  List<AppMessage> _messages = const [];

  MessageService({
    MessageRepository? repository,
    AppNotificationService? notificationService,
    int maxMessages = 200,
  }) : _repository = repository ?? MessageRepository(),
       _notificationService = notificationService,
       _maxMessages = maxMessages;

  List<AppMessage> get messages => List.unmodifiable(_messages);
  List<AppMessage> get unreadMessages =>
      List.unmodifiable(_messages.where((e) => !e.isRead));

  Future<void> init() async {
    await purgeExpired(now: DateTime.now());
    await _reload();
  }

  Future<void> _reload({bool notify = true}) async {
    _messages = await _repository.listMessages(limit: _maxMessages);
    if (notify) notifyListeners();
  }

  Future<int?> upsertMessage({
    required String toolId,
    required String title,
    required String body,
    String? dedupeKey,
    String? route,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool notify = false,
    bool markUnreadOnUpdate = true,
    bool refreshDaily = false,
  }) async {
    final trimmedBody = body.trim();
    final existing = _findByDedupeKey(dedupeKey);

    final effectiveNow = createdAt ?? DateTime.now();
    final effectiveExpiresAt =
        expiresAt ??
        DateTime(
          effectiveNow.year,
          effectiveNow.month,
          effectiveNow.day,
        ).add(defaultExpiresIn);
    final shouldResurfaceDaily =
        refreshDaily &&
        existing != null &&
        _isDifferentDay(existing.createdAt, effectiveNow);

    // 关键行为：同一条 dedupeKey 的消息若“内容未变”，则不应写库：
    // - 避免 createdAt 被刷新导致排序跳动
    // - 避免 markUnreadOnUpdate 把已读重置为未读
    // - 避免重复推送系统通知
    if (existing != null) {
      final noOpUpdate =
          existing.toolId == toolId &&
          existing.title == title &&
          existing.body == trimmedBody &&
          existing.route == route &&
          existing.expiresAt == effectiveExpiresAt;
      if (noOpUpdate && !shouldResurfaceDaily) {
        return existing.id;
      }
    }

    final contentChanged =
        existing == null ||
        existing.toolId != toolId ||
        existing.title != title ||
        existing.body != trimmedBody ||
        existing.route != route ||
        existing.expiresAt != effectiveExpiresAt ||
        shouldResurfaceDaily ||
        (markUnreadOnUpdate && existing.isRead);

    final id = await _repository.upsertMessage(
      toolId: toolId,
      title: title,
      body: trimmedBody,
      dedupeKey: dedupeKey,
      route: route,
      createdAt: createdAt ?? effectiveNow,
      expiresAt: effectiveExpiresAt,
      markUnreadOnUpdate: markUnreadOnUpdate,
    );
    if (id == null) return null;

    await _reload();

    if (notify && contentChanged) {
      await _notificationService?.showMessage(title: title, body: trimmedBody);
    }
    return id;
  }

  AppMessage? _findByDedupeKey(String? dedupeKey) {
    if (dedupeKey == null) return null;
    for (final message in _messages) {
      if (message.dedupeKey == dedupeKey) return message;
    }
    return null;
  }

  bool _isDifferentDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  Future<void> markMessageRead(int id, {DateTime? readAt}) async {
    await _repository.markRead(id, readAt: readAt);
    await _reload();
  }

  Future<void> deleteMessage(int id) async {
    await _repository.deleteById(id);
    await _reload();
  }

  Future<void> deleteMessageByDedupeKey(String dedupeKey) async {
    await _repository.deleteByDedupeKey(dedupeKey);
    await _reload();
  }

  Future<void> scheduleSystemNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    await _notificationService?.scheduleMessage(
      id: id,
      title: title,
      body: body,
      scheduledAt: scheduledAt,
    );
  }

  Future<void> cancelSystemNotification(int id) async {
    await _notificationService?.cancel(id);
  }

  Future<int> purgeExpired({required DateTime now}) async {
    final deleted = await _repository.deleteExpired(now);
    if (deleted > 0) {
      await _reload();
    }
    return deleted;
  }
}
