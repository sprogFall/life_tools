class OvercookedWishItem {
  final int id;
  final int dayKey;
  final int recipeId;
  final DateTime createdAt;

  const OvercookedWishItem({
    required this.id,
    required this.dayKey,
    required this.recipeId,
    required this.createdAt,
  });

  static OvercookedWishItem fromRow(Map<String, Object?> row) {
    return OvercookedWishItem(
      id: row['id'] as int,
      dayKey: row['day_key'] as int,
      recipeId: row['recipe_id'] as int,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }
}

