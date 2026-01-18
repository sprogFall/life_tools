enum StockItemStockStatus { inStock, depleted, all }

class StockItem {
  final int? id;
  final String name;
  final String location;
  final String unit;
  final double totalQuantity;
  final double remainingQuantity;
  final DateTime purchaseDate;
  final DateTime? expiryDate;
  final int remindDays;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StockItem({
    this.id,
    required this.name,
    required this.location,
    required this.unit,
    required this.totalQuantity,
    required this.remainingQuantity,
    required this.purchaseDate,
    required this.expiryDate,
    required this.remindDays,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StockItem.create({
    required String name,
    required String location,
    required String unit,
    required double totalQuantity,
    required double remainingQuantity,
    required DateTime purchaseDate,
    required DateTime? expiryDate,
    required int remindDays,
    required String note,
    required DateTime now,
  }) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('createItem 需要 name');
    }
    if (totalQuantity < 0) {
      throw ArgumentError('totalQuantity 不能小于 0');
    }
    if (remainingQuantity < 0) {
      throw ArgumentError('remainingQuantity 不能小于 0');
    }
    if (remainingQuantity > totalQuantity) {
      throw ArgumentError('remainingQuantity 不能大于 totalQuantity');
    }
    if (remindDays < -1) {
      throw ArgumentError('remindDays 不能小于 -1');
    }

    return StockItem(
      name: trimmedName,
      location: location.trim(),
      unit: unit.trim(),
      totalQuantity: totalQuantity,
      remainingQuantity: remainingQuantity,
      purchaseDate: _startOfDay(purchaseDate),
      expiryDate: expiryDate == null ? null : _startOfDay(expiryDate),
      remindDays: remindDays,
      note: note.trim(),
      createdAt: now,
      updatedAt: now,
    );
  }

  bool get isDepleted => remainingQuantity <= 0;

  bool isExpired(DateTime now) {
    final e = expiryDate;
    if (e == null) return false;
    return _startOfDay(e).isBefore(_startOfDay(now));
  }

  bool isExpiringSoon(DateTime now) {
    final e = expiryDate;
    if (e == null) return false;
    if (remindDays < 0) return false;
    final threshold = _startOfDay(now).add(Duration(days: remindDays));
    return _startOfDay(e).millisecondsSinceEpoch <=
        threshold.millisecondsSinceEpoch;
  }

  StockItem copyWith({
    int? id,
    String? name,
    String? location,
    String? unit,
    double? totalQuantity,
    double? remainingQuantity,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    int? remindDays,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StockItem(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      unit: unit ?? this.unit,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      remindDays: remindDays ?? this.remindDays,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    final map = <String, Object?>{
      'name': name,
      'location': location,
      'total_quantity': totalQuantity,
      'remaining_quantity': remainingQuantity,
      'unit': unit,
      'purchase_date': _startOfDay(purchaseDate).millisecondsSinceEpoch,
      'expiry_date': expiryDate == null
          ? null
          : _startOfDay(expiryDate!).millisecondsSinceEpoch,
      'remind_days': remindDays,
      'note': note,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  static StockItem fromMap(Map<String, Object?> map) {
    return StockItem(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      location: (map['location'] as String?) ?? '',
      unit: (map['unit'] as String?) ?? '',
      totalQuantity: _asDouble(map['total_quantity']),
      remainingQuantity: _asDouble(map['remaining_quantity']),
      purchaseDate: DateTime.fromMillisecondsSinceEpoch(
        map['purchase_date'] as int,
      ),
      expiryDate: map['expiry_date'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['expiry_date'] as int),
      remindDays: (map['remind_days'] as int?) ?? 3,
      note: (map['note'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  static double _asDouble(Object? v) {
    if (v == null) return 0;
    return (v as num).toDouble();
  }

  static DateTime _startOfDay(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }
}
