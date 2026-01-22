import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/stockpile_assistant/models/stock_item.dart';
import 'package:life_tools/tools/stockpile_assistant/services/stockpile_reminder_service.dart';

void main() {
  group('囤货助手-补货提醒', () {
    test('提醒日期：到日期（含当天）触发', () {
      final now = DateTime(2026, 1, 10, 10);
      final item = StockItem.create(
        name: '牛奶',
        location: '',
        unit: '盒',
        totalQuantity: 10,
        remainingQuantity: 5,
        purchaseDate: now,
        expiryDate: null,
        remindDays: -1,
        restockRemindDate: DateTime(2026, 1, 10),
        restockRemindQuantity: null,
        note: '',
        now: now,
      );

      expect(item.isRestockDue(DateTime(2026, 1, 9, 23, 59)), isFalse);
      expect(item.isRestockDue(DateTime(2026, 1, 10, 0, 0)), isTrue);
      expect(item.isRestockDue(DateTime(2026, 1, 11, 0, 0)), isTrue);
    });

    test('提醒库存：库存 <= 阈值触发', () {
      final now = DateTime(2026, 1, 10, 10);
      final base = StockItem.create(
        name: '抽纸',
        location: '',
        unit: '包',
        totalQuantity: 10,
        remainingQuantity: 5,
        purchaseDate: now,
        expiryDate: null,
        remindDays: -1,
        restockRemindDate: null,
        restockRemindQuantity: 2,
        note: '',
        now: now,
      );

      expect(base.copyWith(remainingQuantity: 2).isRestockDue(now), isTrue);
      expect(base.copyWith(remainingQuantity: 2.01).isRestockDue(now), isFalse);
      expect(base.copyWith(remainingQuantity: 1).isRestockDue(now), isTrue);
    });

    test('补货提醒：字段序列化/反序列化', () {
      final now = DateTime(2026, 1, 10, 10);
      final item = StockItem.create(
        name: '面包',
        location: '厨房',
        unit: '个',
        totalQuantity: 6,
        remainingQuantity: 3,
        purchaseDate: DateTime(2026, 1, 1),
        expiryDate: DateTime(2026, 1, 20),
        remindDays: 3,
        restockRemindDate: DateTime(2026, 1, 12),
        restockRemindQuantity: 2,
        note: '测试',
        now: now,
      );

      final map = item.toMap(includeId: false);
      expect(
        map['restock_remind_date'],
        DateTime(2026, 1, 12).millisecondsSinceEpoch,
      );
      expect(map['restock_remind_quantity'], 2.0);

      final from = StockItem.fromMap({...map, 'id': 1});
      expect(from.restockRemindDate, DateTime(2026, 1, 12));
      expect(from.restockRemindQuantity, 2.0);
    });

    test('补货提醒文案：库存触发', () {
      final now = DateTime(2026, 1, 10, 10);
      final item = StockItem.create(
        name: '洗衣液',
        location: '阳台',
        unit: '瓶',
        totalQuantity: 2,
        remainingQuantity: 1,
        purchaseDate: now,
        expiryDate: null,
        remindDays: -1,
        restockRemindDate: null,
        restockRemindQuantity: 1,
        note: '',
        now: now,
      );

      final body = StockpileReminderService.buildRestockBody(
        item: item,
        now: now,
      );
      expect(body, contains('需要补货'));
      expect(body, contains('剩余'));
    });
  });
}
