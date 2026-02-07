import '../../../core/ai/ai_json_utils.dart';
import '../models/stockpile_drafts.dart';

sealed class StockpileAiIntent {
  const StockpileAiIntent();
}

class UnknownIntent extends StockpileAiIntent {
  final String reason;
  final Map<String, Object?>? raw;

  const UnknownIntent({required this.reason, this.raw});
}

class StockpileAiItemRef {
  final int? id;
  final String? name;

  const StockpileAiItemRef({this.id, this.name});
}

class CreateItemIntent extends StockpileAiIntent {
  final StockItemDraft draft;

  const CreateItemIntent({required this.draft});
}

class AddConsumptionIntent extends StockpileAiIntent {
  final StockpileAiItemRef itemRef;
  final StockConsumptionDraft draft;

  const AddConsumptionIntent({required this.itemRef, required this.draft});
}

class StockpileAiConsumptionEntry {
  final StockpileAiItemRef itemRef;
  final StockConsumptionDraft draft;

  const StockpileAiConsumptionEntry({
    required this.itemRef,
    required this.draft,
  });
}

class BatchEntryIntent extends StockpileAiIntent {
  final List<StockItemDraft> items;
  final List<StockpileAiConsumptionEntry> consumptions;

  const BatchEntryIntent({required this.items, required this.consumptions});
}

class StockpileAiIntentParser {
  static StockpileAiIntent parse(String text) {
    final map = AiJsonUtils.decodeFirstObject(text);
    if (map == null) return const UnknownIntent(reason: '无法解析 JSON');

    final type = AiJsonUtils.asString(map['type'])?.trim();
    if (type == null || type.isEmpty) {
      return UnknownIntent(reason: '缺少 type 字段', raw: map);
    }

    switch (type) {
      case 'create_item':
        return _parseCreateItem(map);
      case 'add_consumption':
        return _parseAddConsumption(map);
      case 'batch_entry':
        return _parseBatchEntry(map);
      default:
        return UnknownIntent(reason: '不支持的 type: $type', raw: map);
    }
  }

  static StockpileAiIntent _parseCreateItem(Map<String, Object?> root) {
    final item = AiJsonUtils.asMap(root['item']);
    if (item == null) {
      return UnknownIntent(reason: 'create_item 缺少 item 对象', raw: root);
    }

    final parsed = _parseStockItemDraft(item);
    if (parsed.error != null) {
      return UnknownIntent(reason: 'create_item ${parsed.error}', raw: root);
    }

    return CreateItemIntent(draft: parsed.draft!);
  }

  static StockpileAiIntent _parseAddConsumption(Map<String, Object?> root) {
    final parsed = _parseConsumptionEntry(
      root,
      missingConsumptionError: 'add_consumption 缺少 consumption 对象',
      invalidQuantityError: 'add_consumption 缺少有效的 consumption.quantity',
    );
    if (parsed.error != null) {
      return UnknownIntent(reason: parsed.error!, raw: root);
    }

    return AddConsumptionIntent(
      itemRef: parsed.entry!.itemRef,
      draft: parsed.entry!.draft,
    );
  }

  static StockpileAiIntent _parseBatchEntry(Map<String, Object?> root) {
    final items = <StockItemDraft>[];
    final consumptions = <StockpileAiConsumptionEntry>[];

    final itemsRaw = AiJsonUtils.asList(root['items']);
    if (itemsRaw != null) {
      for (var i = 0; i < itemsRaw.length; i++) {
        final itemMap = AiJsonUtils.asMap(itemsRaw[i]);
        if (itemMap == null) {
          return UnknownIntent(reason: 'batch_entry.items[$i] 不是对象', raw: root);
        }
        final parsed = _parseStockItemDraft(itemMap);
        if (parsed.error != null) {
          return UnknownIntent(
            reason: 'batch_entry.items[$i] ${parsed.error}',
            raw: root,
          );
        }
        items.add(parsed.draft!);
      }
    }

    final consumptionsRaw = AiJsonUtils.asList(root['consumptions']);
    if (consumptionsRaw != null) {
      for (var i = 0; i < consumptionsRaw.length; i++) {
        final entryMap = AiJsonUtils.asMap(consumptionsRaw[i]);
        if (entryMap == null) {
          return UnknownIntent(
            reason: 'batch_entry.consumptions[$i] 不是对象',
            raw: root,
          );
        }
        final parsed = _parseConsumptionEntry(
          entryMap,
          missingConsumptionError:
              'batch_entry.consumptions[$i] 缺少 consumption 对象',
          invalidQuantityError:
              'batch_entry.consumptions[$i] 缺少有效的 consumption.quantity',
        );
        if (parsed.error != null) {
          return UnknownIntent(reason: parsed.error!, raw: root);
        }
        consumptions.add(parsed.entry!);
      }
    }

    if (items.isEmpty && consumptions.isEmpty) {
      return UnknownIntent(
        reason: 'batch_entry 缺少 items/consumptions',
        raw: root,
      );
    }

    return BatchEntryIntent(items: items, consumptions: consumptions);
  }

  static ({StockItemDraft? draft, String? error}) _parseStockItemDraft(
    Map<String, Object?> item,
  ) {
    final name = AiJsonUtils.asString(item['name'])?.trim();
    if (name == null || name.isEmpty) {
      return (draft: null, error: '缺少 item.name');
    }

    final total = AiJsonUtils.asDouble(item['total_quantity']) ?? 1;
    final remaining = AiJsonUtils.asDouble(item['remaining_quantity']) ?? total;
    final purchaseDate =
        AiJsonUtils.parseDateOnly(
          AiJsonUtils.asString(item['purchase_date']),
        ) ??
        DateTime.now();
    final expiryDate = AiJsonUtils.parseDateOnly(
      AiJsonUtils.asString(item['expiry_date']),
    );
    final restockRemindDate = AiJsonUtils.parseDateOnly(
      AiJsonUtils.asString(item['restock_remind_date']),
    );
    final restockRemindQuantity = AiJsonUtils.asDouble(
      item['restock_remind_quantity'],
    );

    final tagIds =
        AiJsonUtils.asList(
          item['tag_ids'],
        )?.map(AiJsonUtils.asInt).whereType<int>().toList(growable: false) ??
        const <int>[];

    return (
      draft: StockItemDraft(
        name: name,
        location: AiJsonUtils.asString(item['location'])?.trim() ?? '',
        totalQuantity: total,
        remainingQuantity: remaining,
        unit: AiJsonUtils.asString(item['unit'])?.trim() ?? '',
        purchaseDate: purchaseDate,
        expiryDate: expiryDate,
        remindDays: AiJsonUtils.asInt(item['remind_days']) ?? 3,
        restockRemindDate: restockRemindDate,
        restockRemindQuantity: restockRemindQuantity,
        note: AiJsonUtils.asString(item['note'])?.trim() ?? '',
        tagIds: tagIds,
      ),
      error: null,
    );
  }

  static ({StockpileAiConsumptionEntry? entry, String? error})
  _parseConsumptionEntry(
    Map<String, Object?> root, {
    required String missingConsumptionError,
    required String invalidQuantityError,
  }) {
    final itemRefMap = AiJsonUtils.asMap(root['item_ref']);
    final itemRef = StockpileAiItemRef(
      id: itemRefMap != null ? AiJsonUtils.asInt(itemRefMap['id']) : null,
      name: itemRefMap != null
          ? AiJsonUtils.asString(itemRefMap['name'])?.trim()
          : null,
    );

    final consumption = AiJsonUtils.asMap(root['consumption']);
    if (consumption == null) {
      return (entry: null, error: missingConsumptionError);
    }

    final quantity = AiJsonUtils.asDouble(consumption['quantity']);
    if (quantity == null || quantity <= 0) {
      return (entry: null, error: invalidQuantityError);
    }

    final consumedAt =
        AiJsonUtils.parseDateTime(
          AiJsonUtils.asString(consumption['consumed_at']),
        ) ??
        DateTime.now();

    return (
      entry: StockpileAiConsumptionEntry(
        itemRef: itemRef,
        draft: StockConsumptionDraft(
          quantity: quantity,
          method: AiJsonUtils.asString(consumption['method'])?.trim() ?? '',
          consumedAt: consumedAt,
          note: AiJsonUtils.asString(consumption['note'])?.trim() ?? '',
        ),
      ),
      error: null,
    );
  }
}
