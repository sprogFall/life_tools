import '../../../core/sync/interfaces/tool_sync_provider.dart';
import '../repository/overcooked_repository.dart';

class OvercookedSyncProvider implements ToolSyncProvider {
  final OvercookedRepository _repository;

  OvercookedSyncProvider({required OvercookedRepository repository})
    : _repository = repository;

  @override
  String get toolId => 'overcooked_kitchen';

  @override
  Future<Map<String, dynamic>> exportData() async {
    final recipes = await _repository.exportRecipes();
    final ingredientTags = await _repository.exportRecipeIngredientTags();
    final sauceTags = await _repository.exportRecipeSauceTags();
    final flavorTags = await _repository.exportRecipeFlavorTags();
    final wishItems = await _repository.exportWishItems();
    final mealDays = await _repository.exportMealDays();
    final mealItems = await _repository.exportMealItems();

    return {
      'version': 2,
      'data': {
        'recipes': recipes,
        'recipe_ingredient_tags': ingredientTags,
        'recipe_sauce_tags': sauceTags,
        'recipe_flavor_tags': flavorTags,
        'wish_items': wishItems,
        'meal_days': mealDays,
        'meal_items': mealItems,
      },
    };
  }

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    final version = data['version'] as int?;
    if (version != 1 && version != 2) {
      throw Exception('不支持的数据版本: $version');
    }

    final dataMap = data['data'] as Map<String, dynamic>?;
    if (dataMap == null) {
      throw Exception('数据格式错误：缺少 data 字段');
    }

    List<Map<String, dynamic>> readList(String key) {
      final raw = dataMap[key];
      if (raw is! List) return const [];
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    await _repository.importFromServer(
      recipes: readList('recipes'),
      ingredientTags: readList('recipe_ingredient_tags'),
      sauceTags: readList('recipe_sauce_tags'),
      flavorTags: readList('recipe_flavor_tags'),
      wishItems: readList('wish_items'),
      mealDays: readList('meal_days'),
      mealItems: readList('meal_items'),
    );
  }
}
