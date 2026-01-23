import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_meal.dart';
import 'package:life_tools/tools/overcooked_kitchen/utils/overcooked_meal_stats.dart';

void main() {
  group('OvercookedMealStats', () {
    test('今日做菜量应按“菜谱去重”计数', () {
      final meals = [
        OvercookedMeal(
          id: 1,
          dayKey: 20260110,
          mealTagId: 1,
          note: '',
          sortIndex: 0,
          recipeIds: const [10, 11, 10],
        ),
        OvercookedMeal(
          id: 2,
          dayKey: 20260110,
          mealTagId: 2,
          note: '',
          sortIndex: 1,
          recipeIds: const [11, 12],
        ),
      ];

      expect(distinctRecipeCount(meals), 3);
    });
  });
}
