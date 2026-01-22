class OvercookedMeal {
  final int dayKey;
  final String note;
  final String mealSlot;
  final List<int> recipeIds;

  const OvercookedMeal({
    required this.dayKey,
    required this.note,
    required this.mealSlot,
    required this.recipeIds,
  });
}
