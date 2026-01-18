import '../../../core/messages/message_service.dart';
import '../models/stock_item.dart';
import '../repository/stockpile_repository.dart';
import '../utils/stockpile_utils.dart';

class StockpileReminderService {
  final StockpileRepository _repository;

  StockpileReminderService({StockpileRepository? repository})
    : _repository = repository ?? StockpileRepository();

  static const int _notificationIdStride = 100;
  static const int _notificationIdBase = 1000000;
  static const int _maxScheduledNotificationsPerItem = 40;
  static const int _maxScheduledDays = 30;
  static const int _defaultNotificationHour = 9;

  Future<void> syncReminderForItem({
    required MessageService messageService,
    required StockItem item,
    DateTime? now,
  }) async {
    final time = now ?? DateTime.now();
    await _syncItem(messageService: messageService, item: item, time: time);
  }

  Future<void> pushDueReminders({
    required MessageService messageService,
    DateTime? now,
  }) async {
    final time = now ?? DateTime.now();
    final items = await _repository.listItems(
      stockStatus: StockItemStockStatus.all,
    );

    for (final item in items) {
      await _syncItem(messageService: messageService, item: item, time: time);
    }
  }

  static String dedupeKeyForItem({required int itemId}) {
    return 'stockpile:expiry:$itemId';
  }

  Future<void> _syncItem({
    required MessageService messageService,
    required StockItem item,
    required DateTime time,
  }) async {
    final id = item.id;
    if (id == null) return;

    final dedupeKey = dedupeKeyForItem(itemId: id);

    await _syncScheduledNotifications(
      messageService: messageService,
      item: item,
      now: time,
    );

    if (item.isDepleted || item.expiryDate == null || item.remindDays < 0) {
      await messageService.deleteMessageByDedupeKey(dedupeKey);
      return;
    }

    final expired = item.isExpired(time);
    final expiringSoon = item.isExpiringSoon(time);
    if (!expired && !expiringSoon) {
      await messageService.deleteMessageByDedupeKey(dedupeKey);
      return;
    }

    await messageService.upsertMessage(
      toolId: 'stockpile_assistant',
      title: '囤货助手',
      body: buildBody(item: item, now: time),
      dedupeKey: dedupeKey,
      route: 'tool://stockpile_assistant',
      createdAt: time,
      notify: true,
    );
  }

  static String buildBody({required StockItem item, required DateTime now}) {
    final expiry = item.expiryDate;
    if (expiry == null) {
      return '【囤货助手】${item.name} 已设置提醒，但未填写到期日期';
    }

    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiry.year, expiry.month, expiry.day);
    final daysLeft = exp.difference(today).inDays;

    final location = item.location.trim();
    final locationText = location.isEmpty ? '' : '（$location）';
    final qtyText =
        '${StockpileFormat.num(item.remainingQuantity)}${item.unit}';
    final dateText = StockpileFormat.date(exp);

    if (daysLeft < 0) {
      final daysAgo = -daysLeft;
      final agoText = daysAgo == 1 ? '已过期 1 天' : '已过期 $daysAgo 天';
      return '【囤货助手】${item.name}$locationText $agoText（$dateText 到期），剩余 $qtyText。';
    }

    if (daysLeft == 0) {
      return '【囤货助手】${item.name}$locationText 今天到期（$dateText），剩余 $qtyText。';
    }

    return '【囤货助手】${item.name}$locationText 将在 $daysLeft 天后到期（$dateText），剩余 $qtyText。';
  }

  static int _notificationIdForItem(int itemId, int index) {
    return _notificationIdBase + itemId * _notificationIdStride + index;
  }

  static Future<void> cancelScheduledNotificationsForItem({
    required MessageService messageService,
    required int itemId,
  }) async {
    for (var i = 0; i < _maxScheduledNotificationsPerItem; i++) {
      await messageService.cancelSystemNotification(
        _notificationIdForItem(itemId, i),
      );
    }
  }

  Future<void> _syncScheduledNotifications({
    required MessageService messageService,
    required StockItem item,
    required DateTime now,
  }) async {
    final id = item.id;
    if (id == null) return;

    await cancelScheduledNotificationsForItem(
      messageService: messageService,
      itemId: id,
    );

    final expiry = item.expiryDate;
    if (item.isDepleted || expiry == null) return;
    if (item.remindDays < 0) return;
    if (item.isExpired(now)) return;

    final remindDays = item.remindDays.clamp(0, _maxScheduledDays);
    final start = expiry.subtract(Duration(days: remindDays));
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(expiry.year, expiry.month, expiry.day);
    final dayCount = endDay.difference(startDay).inDays;
    if (dayCount < 0) return;

    for (var i = 0; i <= dayCount; i++) {
      final d = startDay.add(Duration(days: i));
      final scheduledAt = DateTime(
        d.year,
        d.month,
        d.day,
        _defaultNotificationHour,
      );
      if (!scheduledAt.isAfter(now)) continue;

      await messageService.scheduleSystemNotification(
        id: _notificationIdForItem(id, i),
        title: '囤货助手',
        body: buildBody(item: item, now: scheduledAt),
        scheduledAt: scheduledAt,
      );
    }
  }
}
