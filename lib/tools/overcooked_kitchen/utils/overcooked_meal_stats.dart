import '../models/overcooked_meal.dart';

int distinctRecipeCount(Iterable<OvercookedMeal> meals) {
  return meals.expand((m) => m.recipeIds).toSet().length;
}
