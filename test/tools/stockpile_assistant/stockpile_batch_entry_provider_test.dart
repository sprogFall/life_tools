import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/stockpile_assistant/ai/stockpile_ai_intent.dart';
import 'package:life_tools/tools/stockpile_assistant/models/stockpile_drafts.dart';
import 'package:life_tools/tools/stockpile_assistant/providers/stockpile_batch_entry_provider.dart';

void main() {
  test('StockpileBatchEntryProvider：无物品但有消耗时默认切到消耗页', () {
    final provider = StockpileBatchEntryProvider(
      initialItems: const [],
      initialConsumptions: [
        StockpileAiConsumptionEntry(
          itemRef: const StockpileAiItemRef(name: '牛奶'),
          draft: StockConsumptionDraft(
            quantity: 1,
            method: '',
            consumedAt: DateTime(2026, 1, 2, 9),
            note: '',
          ),
        ),
      ],
    );
    expect(provider.tab, 1);
    provider.dispose();
  });

  test('StockpileBatchEntryProvider：物品条目 keyId 递增且删除会释放资源', () {
    final provider = StockpileBatchEntryProvider(
      initialItems: [
        StockItemDraft(
          name: '牛奶',
          location: '',
          totalQuantity: 1,
          remainingQuantity: 1,
          unit: '',
          purchaseDate: DateTime(2026, 1, 1),
          expiryDate: null,
          remindDays: -1,
          restockRemindDate: null,
          restockRemindQuantity: null,
          note: '',
        ),
      ],
      initialConsumptions: const <StockpileAiConsumptionEntry>[],
    );

    expect(provider.items.map((e) => e.keyId).toList(), [0]);

    provider.addEmptyItem();
    expect(provider.items.map((e) => e.keyId).toList(), [0, 1]);

    final removed = provider.items.first;
    provider.removeItem(removed);
    expect(provider.items.map((e) => e.keyId).toList(), [1]);

    provider.dispose();
  });

  test('StockpileBatchEntryProvider：消耗条目 keyId 递增且删除会释放资源', () {
    final provider = StockpileBatchEntryProvider(
      initialItems: const [],
      initialConsumptions: const [],
    );

    expect(provider.consumptions, isEmpty);

    provider.addEmptyConsumption();
    expect(provider.consumptions.map((e) => e.keyId).toList(), [0]);

    provider.addEmptyConsumption();
    expect(provider.consumptions.map((e) => e.keyId).toList(), [0, 1]);

    final removed = provider.consumptions.first;
    provider.removeConsumption(removed);
    expect(provider.consumptions.map((e) => e.keyId).toList(), [1]);

    provider.dispose();
  });
}
