import 'package:flutter/foundation.dart';

import '../notifications/app_notification_service.dart';
import 'message_repository.dart';
import 'models/app_message.dart';

class MessageService extends ChangeNotifier {
  final MessageRepository _repository;
  final AppNotificationService? _notificationService;
  final int _maxMessages;

  List<AppMessage> _messages = const [];

  MessageService({
    MessageRepository? repository,
    AppNotificationService? notificationService,
    int maxMessages = 200,
  })  : _repository = repository ?? MessageRepository(),
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
  }) async {
    final trimmedBody = body.trim();
    final existing =
        dedupeKey == null
            ? null
            : _messages.where((e) => e.dedupeKey == dedupeKey).isEmpty
            ? null
            : _messages.firstWhere((e) => e.dedupeKey == dedupeKey);

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
          existing.expiresAt == expiresAt;
      if (noOpUpdate) {
        return existing.id;
      }
    }

    final contentChanged =
        existing == null ||
        existing.toolId != toolId ||
        existing.title != title ||
        existing.body != trimmedBody ||
        existing.route != route ||
        existing.expiresAt != expiresAt ||
        (markUnreadOnUpdate && existing.isRead);

    final id = await _repository.upsertMessage(
      toolId: toolId,
      title: title,
      body: trimmedBody,
      dedupeKey: dedupeKey,
      route: route,
      createdAt: createdAt,
      expiresAt: expiresAt,
      markUnreadOnUpdate: markUnreadOnUpdate,
    );
    if (id == null) return null;

    await _reload();

    if (notify && contentChanged) {
      await _notificationService?.showMessage(title: title, body: trimmedBody);
    }
    return id;
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
