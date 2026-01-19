import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/tags/models/tag.dart';
import 'package:life_tools/tools/stockpile_assistant/ai/stockpile_ai_context.dart';
import 'package:life_tools/tools/stockpile_assistant/models/stock_item.dart';

void main() {
  group('buildStockpileAiContext', () {
    test('没有可用标签时：不输出标签区块', () {
      final text = buildStockpileAiContext(
        now: DateTime(2026, 1, 2, 9),
        items: const [],
        tags: const [],
      );
      expect(text.contains('可用标签'), false);
    });

    test('有可用标签时：输出标签 id/name 供 AI 选择', () {
      final now = DateTime(2026, 1, 2, 9);
      final tagNow = DateTime(2026, 1, 1);
      final text = buildStockpileAiContext(
        now: now,
        items: [
          StockItem(
            id: 12,
            name: '牛奶',
            location: '冰箱',
            unit: '盒',
            totalQuantity: 2,
            remainingQuantity: 1,
            purchaseDate: DateTime(2026, 1, 1),
            expiryDate: DateTime(2026, 1, 5),
            remindDays: 2,
            restockRemindDate: null,
            restockRemindQuantity: null,
            note: '',
            createdAt: now,
            updatedAt: now,
          ),
        ],
        tags: [
          Tag(
            id: 1,
            name: '早餐',
            color: null,
            sortIndex: 0,
            createdAt: tagNow,
            updatedAt: tagNow,
          ),
          Tag(
            id: 3,
            name: '冷藏',
            color: null,
            sortIndex: 1,
            createdAt: tagNow,
            updatedAt: tagNow,
          ),
        ],
      );
      expect(text.contains('可用标签'), true);
      expect(text.contains('[id=1] 早餐'), true);
      expect(text.contains('[id=3] 冷藏'), true);
      expect(text.contains('[id=12] 牛奶'), true);
    });
  });
}
