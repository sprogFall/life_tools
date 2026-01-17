import '../../../core/messages/message_service.dart';
import '../models/stock_item.dart';
import '../repository/stockpile_repository.dart';
import '../utils/stockpile_utils.dart';

class StockpileReminderService {
  final StockpileRepository _repository;

  StockpileReminderService({StockpileRepository? repository})
    : _repository = repository ?? StockpileRepository();

  Future<void> pushDueReminders({
    required MessageService messageService,
    DateTime? now,
  }) async {
    final time = now ?? DateTime.now();
    final items = await _repository.listItems(
      stockStatus: StockItemStockStatus.inStock,
    );

    for (final item in items) {
      if (item.isDepleted) continue;
      if (item.expiryDate == null) continue;
      final id = item.id;
      if (id == null) continue;

      final expired = item.isExpired(time);
      final expiringSoon = item.isExpiringSoon(time);
      if (!expired && !expiringSoon) continue;

      final dedupeKey = _dedupeKeyFor(itemId: id, now: time, expired: expired);
      await messageService.pushMessage(
        toolId: 'stockpile_assistant',
        title: '囤货助手',
        body: _buildBody(item: item, now: time),
        dedupeKey: dedupeKey,
        createdAt: time,
        notify: true,
      );
    }
  }

  static String _dedupeKeyFor({
    required int itemId,
    required DateTime now,
    required bool expired,
  }) {
    final d = DateTime(now.year, now.month, now.day);
    final dayKey = StockpileFormat.date(d);
    final type = expired ? 'expired' : 'expiring';
    return 'stockpile:$type:$itemId:$dayKey';
  }

  static String _buildBody({required StockItem item, required DateTime now}) {
    final expiry = item.expiryDate;
    if (expiry == null) {
      return '【囤货助手】${item.name} 已设置提醒，但未填写到期日期';
    }

    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiry.year, expiry.month, expiry.day);
    final daysLeft = exp.difference(today).inDays;

    final location = item.location.trim();
    final locationText = location.isEmpty ? '' : '（$location）';
    final qtyText = '${StockpileFormat.num(item.remainingQuantity)}${item.unit}';
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
}

