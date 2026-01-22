import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../models/overcooked_meal.dart';
import '../models/overcooked_recipe.dart';
import '../models/overcooked_wish_item.dart';

class OvercookedRepository {
  final Future<Database> _database;

  OvercookedRepository({DatabaseHelper? dbHelper})
    : _database = (dbHelper ?? DatabaseHelper.instance).database;

  OvercookedRepository.withDatabase(Database database)
    : _database = Future.value(database);

  static int dayKey(DateTime dateTime) {
    final d = DateTime(dateTime.year, dateTime.month, dateTime.day);
    return d.year * 10000 + d.month * 100 + d.day;
  }

  static DateTime dateFromDayKey(int key) {
    final year = key ~/ 10000;
    final month = (key % 10000) ~/ 100;
    final day = key % 100;
    return DateTime(year, month, day);
  }

  Future<int> createRecipe(OvercookedRecipe recipe) async {
    final db = await _database;
    return db.transaction((txn) async {
      final row = recipe.toRow()..remove('id');
      final id = await txn.insert('overcooked_recipes', row);

      await _setRecipeTags(
        txn: txn,
        table: 'overcooked_recipe_ingredient_tags',
        recipeId: id,
        tagIds: recipe.ingredientTagIds,
      );
      await _setRecipeTags(
        txn: txn,
        table: 'overcooked_recipe_sauce_tags',
        recipeId: id,
        tagIds: recipe.sauceTagIds,
      );
      await _setRecipeTags(
        txn: txn,
        table: 'overcooked_recipe_flavor_tags',
        recipeId: id,
        tagIds: recipe.flavorTagIds,
      );
      return id;
    });
  }

  Future<void> updateRecipe(OvercookedRecipe recipe, {DateTime? now}) async {
    final id = recipe.id;
    if (id == null) throw ArgumentError('updateRecipe 需要 id');

    final db = await _database;
    final time = now ?? DateTime.now();
    await db.transaction((txn) async {
      final updated = await txn.update(
        'overcooked_recipes',
        recipe.copyWith(updatedAt: time).toRow()..remove('id'),
        where: 'id = ?',
        whereArgs: [id],
      );
      if (updated <= 0) {
        throw StateError('未找到要更新的菜谱 id=$id');
      }

      await _setRecipeTags(
        txn: txn,
        table: 'overcooked_recipe_ingredient_tags',
        recipeId: id,
        tagIds: recipe.ingredientTagIds,
      );
      await _setRecipeTags(
        txn: txn,
        table: 'overcooked_recipe_sauce_tags',
        recipeId: id,
        tagIds: recipe.sauceTagIds,
      );
      await _setRecipeTags(
        txn: txn,
        table: 'overcooked_recipe_flavor_tags',
        recipeId: id,
        tagIds: recipe.flavorTagIds,
      );
    });
  }

  Future<void> deleteRecipe(int recipeId) async {
    final db = await _database;
    await db.delete(
      'overcooked_recipes',
      where: 'id = ?',
      whereArgs: [recipeId],
    );
  }

  Future<OvercookedRecipe?> getRecipe(int id) async {
    final db = await _database;
    final rows = await db.query(
      'overcooked_recipes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final ingredients = await _listRecipeTagIds(
      table: 'overcooked_recipe_ingredient_tags',
      recipeId: id,
    );
    final sauces = await _listRecipeTagIds(
      table: 'overcooked_recipe_sauce_tags',
      recipeId: id,
    );
    final flavors = await _listRecipeTagIds(
      table: 'overcooked_recipe_flavor_tags',
      recipeId: id,
    );
    return OvercookedRecipe.fromRow(
      rows.single,
      ingredientTagIds: ingredients,
      sauceTagIds: sauces,
      flavorTagIds: flavors,
    );
  }

  Future<List<OvercookedRecipe>> listRecipes({int? typeTagId}) async {
    final db = await _database;
    final rows = await db.query(
      'overcooked_recipes',
      where: typeTagId == null ? null : 'type_tag_id = ?',
      whereArgs: typeTagId == null ? null : [typeTagId],
      orderBy: 'updated_at DESC, id DESC',
    );
    if (rows.isEmpty) return const [];

    final ids = rows.map((e) => e['id'] as int).toList();
    final ingredientsByRecipeId = await _listRecipeTagsForRecipes(
      table: 'overcooked_recipe_ingredient_tags',
      recipeIds: ids,
    );
    final saucesByRecipeId = await _listRecipeTagsForRecipes(
      table: 'overcooked_recipe_sauce_tags',
      recipeIds: ids,
    );
    final flavorsByRecipeId = await _listRecipeTagsForRecipes(
      table: 'overcooked_recipe_flavor_tags',
      recipeIds: ids,
    );

    return rows.map((row) {
      final id = row['id'] as int;
      return OvercookedRecipe.fromRow(
        row,
        ingredientTagIds: ingredientsByRecipeId[id] ?? const [],
        sauceTagIds: saucesByRecipeId[id] ?? const [],
        flavorTagIds: flavorsByRecipeId[id] ?? const [],
      );
    }).toList();
  }

  Future<List<OvercookedRecipe>> listRecipesByTypeTagIds(
    List<int> typeTagIds,
  ) async {
    final ids = _dedupeInts(typeTagIds).toList();
    if (ids.isEmpty) return const [];

    final placeholders = List.filled(ids.length, '?').join(',');
    final db = await _database;
    final rows = await db.rawQuery('''
SELECT *
FROM overcooked_recipes
WHERE type_tag_id IN ($placeholders)
ORDER BY updated_at DESC, id DESC
''', ids);
    if (rows.isEmpty) return const [];

    final recipeIds = rows.map((e) => e['id'] as int).toList();
    final ingredientsByRecipeId = await _listRecipeTagsForRecipes(
      table: 'overcooked_recipe_ingredient_tags',
      recipeIds: recipeIds,
    );
    final saucesByRecipeId = await _listRecipeTagsForRecipes(
      table: 'overcooked_recipe_sauce_tags',
      recipeIds: recipeIds,
    );
    final flavorsByRecipeId = await _listRecipeTagsForRecipes(
      table: 'overcooked_recipe_flavor_tags',
      recipeIds: recipeIds,
    );

    return rows.map((row) {
      final id = row['id'] as int;
      return OvercookedRecipe.fromRow(
        row,
        ingredientTagIds: ingredientsByRecipeId[id] ?? const [],
        sauceTagIds: saucesByRecipeId[id] ?? const [],
        flavorTagIds: flavorsByRecipeId[id] ?? const [],
      );
    }).toList();
  }

  Future<List<OvercookedRecipe>> listRecipesByIds(List<int> recipeIds) async {
    final ids = _dedupeInts(recipeIds).toList();
    if (ids.isEmpty) return const [];

    final placeholders = List.filled(ids.length, '?').join(',');
    final db = await _database;
    final rows = await db.rawQuery('''
SELECT *
FROM overcooked_recipes
WHERE id IN ($placeholders)
ORDER BY updated_at DESC, id DESC
''', ids);
    if (rows.isEmpty) return const [];

    final foundIds = rows.map((e) => e['id'] as int).toList();
    final ingredientsByRecipeId = await _listRecipeTagsForRecipes(
      table: 'overcooked_recipe_ingredient_tags',
      recipeIds: foundIds,
    );
    final saucesByRecipeId = await _listRecipeTagsForRecipes(
      table: 'overcooked_recipe_sauce_tags',
      recipeIds: foundIds,
    );
    final flavorsByRecipeId = await _listRecipeTagsForRecipes(
      table: 'overcooked_recipe_flavor_tags',
      recipeIds: foundIds,
    );
    return rows.map((row) {
      final id = row['id'] as int;
      return OvercookedRecipe.fromRow(
        row,
        ingredientTagIds: ingredientsByRecipeId[id] ?? const [],
        sauceTagIds: saucesByRecipeId[id] ?? const [],
        flavorTagIds: flavorsByRecipeId[id] ?? const [],
      );
    }).toList();
  }

  Future<void> addWish({
    required DateTime date,
    required int recipeId,
    DateTime? now,
  }) async {
    final db = await _database;
    await db.insert('overcooked_wish_items', {
      'day_key': dayKey(date),
      'recipe_id': recipeId,
      'created_at': (now ?? DateTime.now()).millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> removeWish({
    required DateTime date,
    required int recipeId,
  }) async {
    final db = await _database;
    await db.delete(
      'overcooked_wish_items',
      where: 'day_key = ? AND recipe_id = ?',
      whereArgs: [dayKey(date), recipeId],
    );
  }

  Future<void> replaceWishes({
    required DateTime date,
    required List<int> recipeIds,
    DateTime? now,
  }) async {
    final db = await _database;
    final key = dayKey(date);
    final time = (now ?? DateTime.now()).millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.delete(
        'overcooked_wish_items',
        where: 'day_key = ?',
        whereArgs: [key],
      );
      for (final id in _dedupeInts(recipeIds)) {
        await txn.insert('overcooked_wish_items', {
          'day_key': key,
          'recipe_id': id,
          'created_at': time,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<List<OvercookedWishItem>> listWishesForDate(DateTime date) async {
    final db = await _database;
    final rows = await db.query(
      'overcooked_wish_items',
      where: 'day_key = ?',
      whereArgs: [dayKey(date)],
      orderBy: 'created_at ASC, id ASC',
    );
    return rows.map(OvercookedWishItem.fromRow).toList();
  }

  Future<void> upsertMealNote({
    required DateTime date,
    required String note,
    String? mealSlot,
    DateTime? now,
  }) async {
    final db = await _database;
    final key = dayKey(date);
    final time = now ?? DateTime.now();
    final slot = mealSlot?.trim();
    await db.transaction((txn) async {
      await txn.insert('overcooked_meal_days', {
        'day_key': key,
        'note': note.trim(),
        if (slot != null) 'meal_slot': slot,
        'created_at': time.millisecondsSinceEpoch,
        'updated_at': time.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'overcooked_meal_days',
        {
          'note': note.trim(),
          if (slot != null) 'meal_slot': slot,
          'updated_at': time.millisecondsSinceEpoch,
        },
        where: 'day_key = ?',
        whereArgs: [key],
      );
    });
  }

  Future<void> replaceMeal({
    required DateTime date,
    required List<int> recipeIds,
    String? mealSlot,
    DateTime? now,
  }) async {
    final db = await _database;
    final key = dayKey(date);
    final time = now ?? DateTime.now();
    final slot = mealSlot?.trim();
    await db.transaction((txn) async {
      await txn.insert('overcooked_meal_days', {
        'day_key': key,
        'note': '',
        if (slot != null) 'meal_slot': slot,
        'created_at': time.millisecondsSinceEpoch,
        'updated_at': time.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.update(
        'overcooked_meal_days',
        {
          if (slot != null) 'meal_slot': slot,
          'updated_at': time.millisecondsSinceEpoch,
        },
        where: 'day_key = ?',
        whereArgs: [key],
      );

      await txn.delete(
        'overcooked_meal_items',
        where: 'day_key = ?',
        whereArgs: [key],
      );
      for (final id in _dedupeInts(recipeIds)) {
        await txn.insert('overcooked_meal_items', {
          'day_key': key,
          'recipe_id': id,
          'created_at': time.millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> replaceMealWithWishes({
    required DateTime date,
    DateTime? now,
  }) async {
    final wishes = await listWishesForDate(date);
    await replaceMeal(
      date: date,
      recipeIds: wishes.map((e) => e.recipeId).toList(),
      now: now,
    );
  }

  Future<OvercookedMeal?> getMealForDate(DateTime date) async {
    final db = await _database;
    final key = dayKey(date);

    final dayRows = await db.query(
      'overcooked_meal_days',
      where: 'day_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (dayRows.isEmpty) return null;

    final itemRows = await db.query(
      'overcooked_meal_items',
      columns: const ['recipe_id'],
      where: 'day_key = ?',
      whereArgs: [key],
      orderBy: 'created_at ASC, recipe_id ASC',
    );
    return OvercookedMeal(
      dayKey: key,
      note: (dayRows.single['note'] as String?) ?? '',
      mealSlot: (dayRows.single['meal_slot'] as String?) ?? '',
      recipeIds: itemRows.map((e) => e['recipe_id'] as int).toList(),
    );
  }

  Future<Map<int, int>> getMonthlyCookCountsByTypeDistinct({
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final startKey = dayKey(start);
    final endKey = dayKey(end);

    final db = await _database;
    final rows = await db.rawQuery(
      '''
SELECT mi.day_key AS day_key, mi.recipe_id AS recipe_id, r.type_tag_id AS type_tag_id
FROM overcooked_meal_items mi
INNER JOIN overcooked_recipes r ON r.id = mi.recipe_id
WHERE mi.day_key >= ? AND mi.day_key <= ?
ORDER BY mi.day_key ASC
''',
      [startKey, endKey],
    );

    final byDay = <int, Set<String>>{};
    for (final row in rows) {
      final key = row['day_key'] as int;
      final typeTagId = row['type_tag_id'] as int?;
      final recipeId = row['recipe_id'] as int;
      final dedupeKey = typeTagId == null ? 'r:$recipeId' : 't:$typeTagId';
      (byDay[key] ??= <String>{}).add(dedupeKey);
    }

    final result = <int, int>{};
    for (final entry in byDay.entries) {
      result[entry.key] = entry.value.length;
    }
    return result;
  }

  Future<List<Map<String, Object?>>> exportRecipes() async {
    final db = await _database;
    final rows = await db.query('overcooked_recipes', orderBy: 'id ASC');
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<List<Map<String, Object?>>> exportRecipeIngredientTags() async {
    final db = await _database;
    final rows = await db.query(
      'overcooked_recipe_ingredient_tags',
      orderBy: 'recipe_id ASC, tag_id ASC',
    );
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<List<Map<String, Object?>>> exportRecipeSauceTags() async {
    final db = await _database;
    final rows = await db.query(
      'overcooked_recipe_sauce_tags',
      orderBy: 'recipe_id ASC, tag_id ASC',
    );
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<List<Map<String, Object?>>> exportRecipeFlavorTags() async {
    final db = await _database;
    final rows = await db.query(
      'overcooked_recipe_flavor_tags',
      orderBy: 'recipe_id ASC, tag_id ASC',
    );
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<List<Map<String, Object?>>> exportWishItems() async {
    final db = await _database;
    final rows = await db.query(
      'overcooked_wish_items',
      orderBy: 'day_key ASC, id ASC',
    );
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<List<Map<String, Object?>>> exportMealDays() async {
    final db = await _database;
    final rows = await db.query('overcooked_meal_days', orderBy: 'day_key ASC');
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<List<Map<String, Object?>>> exportMealItems() async {
    final db = await _database;
    final rows = await db.query(
      'overcooked_meal_items',
      orderBy: 'day_key ASC, recipe_id ASC',
    );
    return rows.map((e) => Map<String, Object?>.from(e)).toList();
  }

  Future<void> importFromServer({
    required List<Map<String, dynamic>> recipes,
    required List<Map<String, dynamic>> ingredientTags,
    required List<Map<String, dynamic>> sauceTags,
    required List<Map<String, dynamic>> flavorTags,
    required List<Map<String, dynamic>> wishItems,
    required List<Map<String, dynamic>> mealDays,
    required List<Map<String, dynamic>> mealItems,
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('overcooked_meal_items');
      await txn.delete('overcooked_meal_days');
      await txn.delete('overcooked_wish_items');
      await txn.delete('overcooked_recipe_ingredient_tags');
      await txn.delete('overcooked_recipe_sauce_tags');
      await txn.delete('overcooked_recipe_flavor_tags');
      await txn.delete('overcooked_recipes');

      for (final row in recipes) {
        await txn.insert('overcooked_recipes', row);
      }
      for (final row in ingredientTags) {
        await txn.insert(
          'overcooked_recipe_ingredient_tags',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final row in sauceTags) {
        await txn.insert(
          'overcooked_recipe_sauce_tags',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final row in flavorTags) {
        await txn.insert(
          'overcooked_recipe_flavor_tags',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final row in wishItems) {
        await txn.insert('overcooked_wish_items', row);
      }
      for (final row in mealDays) {
        await txn.insert('overcooked_meal_days', row);
      }
      for (final row in mealItems) {
        await txn.insert(
          'overcooked_meal_items',
          row,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<void> _setRecipeTags({
    required DatabaseExecutor txn,
    required String table,
    required int recipeId,
    required List<int> tagIds,
  }) async {
    await txn.delete(table, where: 'recipe_id = ?', whereArgs: [recipeId]);

    for (final tagId in _dedupeInts(tagIds)) {
      await txn.insert(table, {
        'recipe_id': recipeId,
        'tag_id': tagId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<List<int>> _listRecipeTagIds({
    required String table,
    required int recipeId,
  }) async {
    final db = await _database;
    final rows = await db.query(
      table,
      columns: const ['tag_id'],
      where: 'recipe_id = ?',
      whereArgs: [recipeId],
      orderBy: 'tag_id ASC',
    );
    return rows.map((e) => e['tag_id'] as int).toList();
  }

  Future<Map<int, List<int>>> _listRecipeTagsForRecipes({
    required String table,
    required List<int> recipeIds,
  }) async {
    final ids = _dedupeInts(recipeIds).toList();
    if (ids.isEmpty) return const {};
    final placeholders = List.filled(ids.length, '?').join(',');
    final db = await _database;
    final rows = await db.rawQuery('''
SELECT recipe_id, tag_id
FROM $table
WHERE recipe_id IN ($placeholders)
ORDER BY recipe_id ASC, tag_id ASC
''', ids);
    final result = <int, List<int>>{};
    for (final row in rows) {
      final recipeId = row['recipe_id'] as int;
      final tagId = row['tag_id'] as int;
      (result[recipeId] ??= <int>[]).add(tagId);
    }
    return result;
  }

  static Iterable<int> _dedupeInts(Iterable<int> values) sync* {
    final seen = <int>{};
    for (final v in values) {
      if (seen.add(v)) yield v;
    }
  }
}
