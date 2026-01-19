class StockItemDraft {
  final String name;
  final String location;
  final double totalQuantity;
  final double remainingQuantity;
  final String unit;
  final DateTime purchaseDate;
  final DateTime? expiryDate;
  final int remindDays;
  final DateTime? restockRemindDate;
  final double? restockRemindQuantity;
  final String note;
  final List<int> tagIds;

  const StockItemDraft({
    required this.name,
    required this.location,
    required this.totalQuantity,
    required this.remainingQuantity,
    required this.unit,
    required this.purchaseDate,
    required this.expiryDate,
    required this.remindDays,
    required this.restockRemindDate,
    required this.restockRemindQuantity,
    required this.note,
    this.tagIds = const [],
  });
}

class StockConsumptionDraft {
  final double quantity;
  final String method;
  final DateTime consumedAt;
  final String note;

  const StockConsumptionDraft({
    required this.quantity,
    required this.method,
    required this.consumedAt,
    required this.note,
  });
}
