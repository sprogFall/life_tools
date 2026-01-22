class StockConsumption {
  final int? id;
  final int itemId;
  final double quantity;
  final String method;
  final DateTime consumedAt;
  final String note;
  final DateTime createdAt;

  const StockConsumption({
    this.id,
    required this.itemId,
    required this.quantity,
    required this.method,
    required this.consumedAt,
    required this.note,
    required this.createdAt,
  });

  factory StockConsumption.create({
    required int itemId,
    required double quantity,
    required String method,
    required DateTime consumedAt,
    required String note,
    required DateTime now,
  }) {
    if (itemId <= 0) {
      throw ArgumentError('createConsumption 需要有效的 itemId');
    }
    if (quantity <= 0) {
      throw ArgumentError('quantity 必须大于 0');
    }
    return StockConsumption(
      itemId: itemId,
      quantity: quantity,
      method: method.trim(),
      consumedAt: consumedAt,
      note: note.trim(),
      createdAt: now,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    final map = <String, Object?>{
      'item_id': itemId,
      'consumed_at': consumedAt.millisecondsSinceEpoch,
      'quantity': quantity,
      'method': method,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  static StockConsumption fromMap(Map<String, Object?> map) {
    return StockConsumption(
      id: map['id'] as int?,
      itemId: map['item_id'] as int,
      consumedAt: DateTime.fromMillisecondsSinceEpoch(
        map['consumed_at'] as int,
      ),
      quantity: _asDouble(map['quantity']),
      method: (map['method'] as String?) ?? '',
      note: (map['note'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  static double _asDouble(Object? v) {
    if (v == null) return 0;
    return (v as num).toDouble();
  }
}
