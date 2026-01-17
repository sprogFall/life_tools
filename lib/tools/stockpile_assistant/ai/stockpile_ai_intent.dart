import 'dart:convert';

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

class StockpileAiIntentParser {
  static StockpileAiIntent parse(String text) {
    final map = _decodeJsonObject(text);
    if (map == null) return const UnknownIntent(reason: '无法解析 JSON');

    final type = _asString(map['type'])?.trim();
    if (type == null || type.isEmpty) {
      return UnknownIntent(reason: '缺少 type 字段', raw: map);
    }

    switch (type) {
      case 'create_item':
        return _parseCreateItem(map);
      case 'add_consumption':
        return _parseAddConsumption(map);
      default:
        return UnknownIntent(reason: '不支持的 type: $type', raw: map);
    }
  }

  static StockpileAiIntent _parseCreateItem(Map<String, Object?> root) {
    final item = _asMap(root['item']);
    if (item == null) {
      return UnknownIntent(reason: 'create_item 缺少 item 对象', raw: root);
    }

    final name = _asString(item['name'])?.trim();
    if (name == null || name.isEmpty) {
      return UnknownIntent(reason: 'create_item 缺少 item.name', raw: root);
    }

    final total = _asDouble(item['total_quantity']) ?? 1;
    final remaining = _asDouble(item['remaining_quantity']) ?? total;
    final purchaseDate =
        _parseDateOnly(_asString(item['purchase_date'])) ?? DateTime.now();
    final expiryDate = _parseDateOnly(_asString(item['expiry_date']));

    return CreateItemIntent(
      draft: StockItemDraft(
        name: name,
        location: _asString(item['location'])?.trim() ?? '',
        totalQuantity: total,
        remainingQuantity: remaining,
        unit: _asString(item['unit'])?.trim() ?? '',
        purchaseDate: purchaseDate,
        expiryDate: expiryDate,
        remindDays: _asInt(item['remind_days']) ?? 3,
        note: _asString(item['note'])?.trim() ?? '',
      ),
    );
  }

  static StockpileAiIntent _parseAddConsumption(Map<String, Object?> root) {
    final itemRefMap = _asMap(root['item_ref']);
    final itemRef = StockpileAiItemRef(
      id: itemRefMap != null ? _asInt(itemRefMap['id']) : null,
      name: itemRefMap != null ? _asString(itemRefMap['name'])?.trim() : null,
    );

    final consumption = _asMap(root['consumption']);
    if (consumption == null) {
      return UnknownIntent(
        reason: 'add_consumption 缺少 consumption 对象',
        raw: root,
      );
    }

    final quantity = _asDouble(consumption['quantity']);
    if (quantity == null || quantity <= 0) {
      return UnknownIntent(
        reason: 'add_consumption 缺少有效的 consumption.quantity',
        raw: root,
      );
    }

    final consumedAt =
        _parseDateTime(_asString(consumption['consumed_at'])) ?? DateTime.now();

    return AddConsumptionIntent(
      itemRef: itemRef,
      draft: StockConsumptionDraft(
        quantity: quantity,
        method: _asString(consumption['method'])?.trim() ?? '',
        consumedAt: consumedAt,
        note: _asString(consumption['note'])?.trim() ?? '',
      ),
    );
  }

  static Map<String, Object?>? _decodeJsonObject(String text) {
    final trimmed = text.trim();
    final decoded = _tryDecodeObject(trimmed);
    if (decoded != null) return decoded;

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final extracted = trimmed.substring(start, end + 1);
    return _tryDecodeObject(extracted);
  }

  static Map<String, Object?>? _tryDecodeObject(String text) {
    try {
      final value = jsonDecode(text);
      if (value is Map) return value.cast<String, Object?>();
      return null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, Object?>();
    return null;
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  static double? _asDouble(Object? value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  static DateTime? _parseDateOnly(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}
