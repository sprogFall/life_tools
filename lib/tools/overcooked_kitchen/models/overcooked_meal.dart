class OvercookedMeal {
  final int id;
  final int dayKey;
  final int? mealTagId;
  final String note;
  final int sortIndex;
  final List<int> recipeIds;

  const OvercookedMeal({
    required this.id,
    required this.dayKey,
    required this.mealTagId,
    required this.note,
    required this.sortIndex,
    required this.recipeIds,
  });
}
