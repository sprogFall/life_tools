import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/stockpile_assistant/ai/stockpile_ai_intent.dart';

void main() {
  group('StockpileAiIntentParser', () {
    test('create_item: 能解析物品草稿', () {
      const json = '''
{
  "type": "create_item",
  "item": {
    "name": "牛奶",
    "location": "冰箱",
    "total_quantity": 2,
    "remaining_quantity": 1,
    "unit": "盒",
    "purchase_date": "2026-01-01",
    "expiry_date": null,
    "remind_days": 3,
    "note": "早餐"
  }
}
''';

      final intent = StockpileAiIntentParser.parse(json);
      expect(intent, isA<CreateItemIntent>());
      final create = intent as CreateItemIntent;
      expect(create.draft.name, '牛奶');
      expect(create.draft.location, '冰箱');
      expect(create.draft.totalQuantity, 2);
      expect(create.draft.remainingQuantity, 1);
      expect(create.draft.unit, '盒');
      expect(create.draft.purchaseDate, DateTime(2026, 1, 1));
      expect(create.draft.expiryDate, isNull);
      expect(create.draft.remindDays, 3);
      expect(create.draft.note, '早餐');
    });

    test('add_consumption: 能解析消耗草稿与 item_ref', () {
      const json = '''
{
  "type": "add_consumption",
  "item_ref": { "id": 12, "name": "牛奶" },
  "consumption": {
    "quantity": 1,
    "method": "喝掉",
    "consumed_at": "2026-01-02T09:00:00",
    "note": "早餐"
  }
}
''';

      final intent = StockpileAiIntentParser.parse(json);
      expect(intent, isA<AddConsumptionIntent>());
      final add = intent as AddConsumptionIntent;
      expect(add.itemRef.id, 12);
      expect(add.itemRef.name, '牛奶');
      expect(add.draft.quantity, 1);
      expect(add.draft.method, '喝掉');
      expect(add.draft.consumedAt, DateTime(2026, 1, 2, 9));
      expect(add.draft.note, '早餐');
    });

    test('未知 type: 返回 UnknownIntent', () {
      const json = '{"type":"nope"}';
      final intent = StockpileAiIntentParser.parse(json);
      expect(intent, isA<UnknownIntent>());
    });

    test('batch_entry: 能解析多物品/多消耗/标签', () {
      const json = '''
{
  "type": "batch_entry",
  "items": [
    {
      "name": "牛奶",
      "location": "冰箱",
      "total_quantity": 2,
      "remaining_quantity": 2,
      "unit": "盒",
      "purchase_date": "2026-01-01",
      "expiry_date": "2026-01-05",
      "remind_days": 2,
      "note": "早餐",
      "tag_ids": [1, 3]
    },
    {
      "name": "面包",
      "location": "",
      "total_quantity": 1,
      "remaining_quantity": 1,
      "unit": "袋",
      "purchase_date": "2026-01-01",
      "expiry_date": null,
      "remind_days": 3,
      "note": "",
      "tag_ids": []
    }
  ],
  "consumptions": [
    {
      "item_ref": { "id": 12, "name": "牛奶" },
      "consumption": {
        "quantity": 1,
        "method": "喝掉",
        "consumed_at": "2026-01-02T09:00:00",
        "note": "早餐"
      }
    }
  ]
}
''';

      final intent = StockpileAiIntentParser.parse(json);
      expect(intent, isA<BatchEntryIntent>());
      final batch = intent as BatchEntryIntent;

      expect(batch.items.length, 2);
      expect(batch.items[0].name, '牛奶');
      expect(batch.items[0].tagIds, [1, 3]);
      expect(batch.items[0].expiryDate, DateTime(2026, 1, 5));
      expect(batch.items[1].name, '面包');
      expect(batch.items[1].tagIds, isEmpty);
      expect(batch.items[1].expiryDate, isNull);

      expect(batch.consumptions.length, 1);
      expect(batch.consumptions[0].itemRef.id, 12);
      expect(batch.consumptions[0].itemRef.name, '牛奶');
      expect(batch.consumptions[0].draft.quantity, 1);
    });
  });
}
