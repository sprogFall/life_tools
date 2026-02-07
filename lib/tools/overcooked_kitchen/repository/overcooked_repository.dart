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

  static String _placeholders(int count) {
    return List.filled(count, '?').join(',');
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
    return _hydrateRecipesFromRows(rows);
  }

  Future<List<OvercookedRecipe>> listRecipesByTypeTagIds(
    List<int> typeTagIds,
  ) async {
    final ids = _dedupeInts(typeTagIds).toList();
    if (ids.isEmpty) return const [];

    final placeholders = _placeholders(ids.length);
    final db = await _database;
    final rows = await db.rawQuery('''
SELECT *
FROM overcooked_recipes
WHERE type_tag_id IN ($placeholders)
ORDER BY updated_at DESC, id DESC
''', ids);
    if (rows.isEmpty) return const [];
    return _hydrateRecipesFromRows(rows);
  }

  Future<Map<int, int>> countRecipesByTypeTagIds(List<int> typeTagIds) async {
    final ids = _dedupeInts(typeTagIds).toList();
    if (ids.isEmpty) return const {};

    final placeholders = _placeholders(ids.length);
    final db = await _database;
    final rows = await db.rawQuery('''
SELECT type_tag_id, COUNT(*) AS recipe_count
FROM overcooked_recipes
WHERE type_tag_id IN ($placeholders)
GROUP BY type_tag_id
''', ids);
    if (rows.isEmpty) return const {};

    final result = <int, int>{};
    for (final row in rows) {
      final typeTagId = row['type_tag_id'] as int?;
      if (typeTagId == null) continue;
      final countValue = row['recipe_count'];
      final count = switch (countValue) {
        int value => value,
        num value => value.toInt(),
        _ => 0,
      };
      result[typeTagId] = count < 0 ? 0 : count;
    }
    return result;
  }

  Future<List<OvercookedRecipe>> listRecipesByIds(List<int> recipeIds) async {
    final ids = _dedupeInts(recipeIds).toList();
    if (ids.isEmpty) return const [];

    final placeholders = _placeholders(ids.length);
    final db = await _database;
    final rows = await db.rawQuery('''
SELECT *
FROM overcooked_recipes
WHERE id IN ($placeholders)
ORDER BY updated_at DESC, id DESC
''', ids);
    if (rows.isEmpty) return const [];
    return _hydrateRecipesFromRows(rows);
  }

  Future<List<OvercookedRecipe>> _hydrateRecipesFromRows(
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return const [];

    final recipeIds = rows.map((e) => e['id'] as int).toList(growable: false);
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

    return rows
        .map((row) {
          final id = row['id'] as int;
          return OvercookedRecipe.fromRow(
            row,
            ingredientTagIds: ingredientsByRecipeId[id] ?? const [],
            sauceTagIds: saucesByRecipeId[id] ?? const [],
            flavorTagIds: flavorsByRecipeId[id] ?? const [],
          );
        })
        .toList(growable: false);
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
    int? mealTagId,
    DateTime? now,
  }) async {
    final db = await _database;
    final key = dayKey(date);
    final time = now ?? DateTime.now();
    final trimmed = note.trim();
    await db.transaction((txn) async {
      final existingId = await _findMealId(
        txn,
        dayKey: key,
        mealTagId: mealTagId,
      );
      if (existingId == null) {
        final sortIndex = await _nextMealSortIndex(txn, dayKey: key);
        await txn.insert('overcooked_meals', {
          'day_key': key,
          'meal_tag_id': mealTagId,
          'note': trimmed,
          'sort_index': sortIndex,
          'created_at': time.millisecondsSinceEpoch,
          'updated_at': time.millisecondsSinceEpoch,
        });
      } else {
        await txn.update(
          'overcooked_meals',
          {'note': trimmed, 'updated_at': time.millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [existingId],
        );
      }
    });
  }

  Future<void> replaceMeal({
    required DateTime date,
    required List<int> recipeIds,
    int? mealTagId,
    DateTime? now,
  }) async {
    final db = await _database;
    final key = dayKey(date);
    final time = now ?? DateTime.now();
    await db.transaction((txn) async {
      var mealId = await _findMealId(txn, dayKey: key, mealTagId: mealTagId);
      if (mealId == null) {
        final sortIndex = await _nextMealSortIndex(txn, dayKey: key);
        mealId = await txn.insert('overcooked_meals', {
          'day_key': key,
          'meal_tag_id': mealTagId,
          'note': '',
          'sort_index': sortIndex,
          'created_at': time.millisecondsSinceEpoch,
          'updated_at': time.millisecondsSinceEpoch,
        });
      } else {
        await txn.update(
          'overcooked_meals',
          {'updated_at': time.millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [mealId],
        );
      }

      await txn.delete(
        'overcooked_meal_items',
        where: 'meal_id = ?',
        whereArgs: [mealId],
      );
      final uniqueIds = _dedupeInts(recipeIds).toList();
      for (int i = 0; i < uniqueIds.length; i++) {
        await txn.insert('overcooked_meal_items', {
          'meal_id': mealId,
          'recipe_id': uniqueIds[i],
          'sort_index': i,
          'created_at': time.millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> replaceMealWithWishes({
    required DateTime date,
    int? mealTagId,
    DateTime? now,
  }) async {
    final wishes = await listWishesForDate(date);
    await replaceMeal(
      date: date,
      recipeIds: wishes.map((e) => e.recipeId).toList(),
      mealTagId: mealTagId,
      now: now,
    );
  }

  Future<void> updateMealTag({
    required int mealId,
    required int? mealTagId,
    DateTime? now,
  }) async {
    final db = await _database;
    final time = now ?? DateTime.now();
    final updated = await db.update(
      'overcooked_meals',
      {'meal_tag_id': mealTagId, 'updated_at': time.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [mealId],
    );
    if (updated <= 0) {
      throw StateError('未找到要更新的餐次记录: id=$mealId');
    }
  }

  Future<void> deleteMeal(int mealId) async {
    final db = await _database;
    await db.delete('overcooked_meals', where: 'id = ?', whereArgs: [mealId]);
  }

  Future<void> updateMealNote({
    required int mealId,
    required String note,
    DateTime? now,
  }) async {
    final db = await _database;
    final time = now ?? DateTime.now();
    final updated = await db.update(
      'overcooked_meals',
      {'note': note.trim(), 'updated_at': time.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [mealId],
    );
    if (updated <= 0) {
      throw StateError('未找到要更新的餐次记录: id=$mealId');
    }
  }

  Future<void> replaceMealItems({
    required int mealId,
    required List<int> recipeIds,
    DateTime? now,
  }) async {
    final db = await _database;
    final time = now ?? DateTime.now();
    await db.transaction((txn) async {
      await txn.update(
        'overcooked_meals',
        {'updated_at': time.millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [mealId],
      );

      await txn.delete(
        'overcooked_meal_items',
        where: 'meal_id = ?',
        whereArgs: [mealId],
      );

      final uniqueIds = _dedupeInts(recipeIds).toList();
      for (int i = 0; i < uniqueIds.length; i++) {
        await txn.insert('overcooked_meal_items', {
          'meal_id': mealId,
          'recipe_id': uniqueIds[i],
          'sort_index': i,
          'created_at': time.millisecondsSinceEpoch,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<List<OvercookedMeal>> listMealsForDate(DateTime date) async {
    final db = await _database;
    final key = dayKey(date);
    final rows = await db.rawQuery(
      '''
SELECT
  m.id AS meal_id,
  m.day_key AS day_key,
  m.meal_tag_id AS meal_tag_id,
  m.note AS note,
  m.sort_index AS meal_sort_index,
  mi.recipe_id AS recipe_id
FROM overcooked_meals m
LEFT JOIN overcooked_meal_items mi ON mi.meal_id = m.id
WHERE m.day_key = ?
ORDER BY m.sort_index ASC, m.created_at ASC, m.id ASC,
         mi.sort_index ASC, mi.created_at ASC, mi.recipe_id ASC
''',
      [key],
    );

    if (rows.isEmpty) return const [];

    final baseByMealId =
        <int, ({int dayKey, int? mealTagId, String note, int sortIndex})>{};
    final recipeIdsByMealId = <int, List<int>>{};
    final orderedMealIds = <int>[];
    for (final row in rows) {
      final mealId = row['meal_id'] as int;
      final recipeId = row['recipe_id'] as int?;
      if (!baseByMealId.containsKey(mealId)) {
        orderedMealIds.add(mealId);
        baseByMealId[mealId] = (
          dayKey: row['day_key'] as int,
          mealTagId: row['meal_tag_id'] as int?,
          note: (row['note'] as String?) ?? '',
          sortIndex: (row['meal_sort_index'] as int?) ?? 0,
        );
      }
      if (recipeId != null) {
        (recipeIdsByMealId[mealId] ??= <int>[]).add(recipeId);
      }
    }

    return [
      for (final id in orderedMealIds)
        OvercookedMeal(
          id: id,
          dayKey: baseByMealId[id]!.dayKey,
          mealTagId: baseByMealId[id]!.mealTagId,
          note: baseByMealId[id]!.note,
          sortIndex: baseByMealId[id]!.sortIndex,
          recipeIds: recipeIdsByMealId[id] ?? const [],
        ),
    ];
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
SELECT m.day_key AS day_key, mi.recipe_id AS recipe_id
FROM overcooked_meal_items mi
INNER JOIN overcooked_meals m ON m.id = mi.meal_id
WHERE m.day_key >= ? AND m.day_key <= ?
ORDER BY m.day_key ASC
''',
      [startKey, endKey],
    );

    final byDay = <int, Set<int>>{};
    for (final row in rows) {
      final key = row['day_key'] as int;
      final recipeId = row['recipe_id'] as int;
      (byDay[key] ??= <int>{}).add(recipeId);
    }

    final result = <int, int>{};
    for (final entry in byDay.entries) {
      result[entry.key] = entry.value.length;
    }
    return result;
  }

  Future<List<Map<String, Object?>>> _exportTable(
    String table, {
    required String orderBy,
  }) async {
    final db = await _database;
    final rows = await db.query(table, orderBy: orderBy);
    return rows
        .map((e) => Map<String, Object?>.from(e))
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> exportRecipes() async {
    return _exportTable('overcooked_recipes', orderBy: 'id ASC');
  }

  Future<List<Map<String, Object?>>> exportRecipeIngredientTags() async {
    return _exportTable(
      'overcooked_recipe_ingredient_tags',
      orderBy: 'recipe_id ASC, tag_id ASC',
    );
  }

  Future<List<Map<String, Object?>>> exportRecipeSauceTags() async {
    return _exportTable(
      'overcooked_recipe_sauce_tags',
      orderBy: 'recipe_id ASC, tag_id ASC',
    );
  }

  Future<List<Map<String, Object?>>> exportRecipeFlavorTags() async {
    return _exportTable(
      'overcooked_recipe_flavor_tags',
      orderBy: 'recipe_id ASC, tag_id ASC',
    );
  }

  Future<List<Map<String, Object?>>> exportWishItems() async {
    return _exportTable(
      'overcooked_wish_items',
      orderBy: 'day_key ASC, id ASC',
    );
  }

  Future<List<Map<String, Object?>>> exportMealDays() async {
    return _exportTable(
      'overcooked_meals',
      orderBy: 'day_key ASC, sort_index ASC, id ASC',
    );
  }

  Future<List<Map<String, Object?>>> exportMealItems() async {
    return _exportTable(
      'overcooked_meal_items',
      orderBy: 'meal_id ASC, sort_index ASC, recipe_id ASC',
    );
  }

  Future<List<Map<String, Object?>>> exportMealItemRatings() async {
    return _exportTable(
      'overcooked_meal_item_ratings',
      orderBy: 'meal_id ASC, recipe_id ASC, id ASC',
    );
  }

  Future<void> _clearAllData(DatabaseExecutor txn) async {
    await txn.delete('overcooked_meal_item_ratings');
    await txn.delete('overcooked_meal_items');
    await txn.delete('overcooked_meals');
    await txn.delete('overcooked_wish_items');
    await txn.delete('overcooked_recipe_ingredient_tags');
    await txn.delete('overcooked_recipe_sauce_tags');
    await txn.delete('overcooked_recipe_flavor_tags');
    await txn.delete('overcooked_recipes');
  }

  Future<void> _bulkInsert(
    DatabaseExecutor txn,
    String table,
    List<Map<String, dynamic>> rows, {
    ConflictAlgorithm? conflictAlgorithm,
  }) async {
    for (final row in rows) {
      await txn.insert(table, row, conflictAlgorithm: conflictAlgorithm);
    }
  }

  Future<void> importFromServer({
    required List<Map<String, dynamic>> recipes,
    required List<Map<String, dynamic>> ingredientTags,
    required List<Map<String, dynamic>> sauceTags,
    required List<Map<String, dynamic>> flavorTags,
    required List<Map<String, dynamic>> wishItems,
    required List<Map<String, dynamic>> meals,
    required List<Map<String, dynamic>> mealItems,
    List<Map<String, dynamic>> mealItemRatings = const [],
  }) async {
    final db = await _database;
    await db.transaction((txn) async {
      await _clearAllData(txn);

      await _bulkInsert(txn, 'overcooked_recipes', recipes);
      await _bulkInsert(
        txn,
        'overcooked_recipe_ingredient_tags',
        ingredientTags,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await _bulkInsert(
        txn,
        'overcooked_recipe_sauce_tags',
        sauceTags,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await _bulkInsert(
        txn,
        'overcooked_recipe_flavor_tags',
        flavorTags,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await _bulkInsert(txn, 'overcooked_wish_items', wishItems);
      await _bulkInsert(txn, 'overcooked_meals', meals);
      await _bulkInsert(
        txn,
        'overcooked_meal_items',
        mealItems,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await _bulkInsert(
        txn,
        'overcooked_meal_item_ratings',
        mealItemRatings,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> importMealItemRatingsFromServer(
    List<Map<String, dynamic>> ratings,
  ) async {
    if (ratings.isEmpty) return;

    final db = await _database;
    await db.transaction((txn) async {
      for (final row in ratings) {
        final mealId = row['meal_id'];
        final recipeId = row['recipe_id'];
        final rating = row['rating'];
        final createdAt = row['created_at'];
        if (mealId is! int ||
            recipeId is! int ||
            rating is! int ||
            createdAt is! int) {
          continue;
        }

        await txn.rawInsert(
          '''
INSERT OR REPLACE INTO overcooked_meal_item_ratings
  (id, meal_id, recipe_id, rating, created_at)
SELECT ?, ?, ?, ?, ?
WHERE EXISTS(SELECT 1 FROM overcooked_meals WHERE id = ?)
  AND EXISTS(SELECT 1 FROM overcooked_recipes WHERE id = ?)
''',
          [row['id'], mealId, recipeId, rating, createdAt, mealId, recipeId],
        );
      }
    });
  }

  Future<void> importFromLegacyServer({
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
      await _clearAllData(txn);

      await _bulkInsert(txn, 'overcooked_recipes', recipes);
      await _bulkInsert(
        txn,
        'overcooked_recipe_ingredient_tags',
        ingredientTags,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await _bulkInsert(
        txn,
        'overcooked_recipe_sauce_tags',
        sauceTags,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await _bulkInsert(
        txn,
        'overcooked_recipe_flavor_tags',
        flavorTags,
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      await _bulkInsert(txn, 'overcooked_wish_items', wishItems);

      if (mealDays.isEmpty) return;

      final itemsByDayKey = <int, List<Map<String, dynamic>>>{};
      for (final row in mealItems) {
        final dayKey = row['day_key'];
        final recipeId = row['recipe_id'];
        if (dayKey is! int || recipeId is! int) continue;
        (itemsByDayKey[dayKey] ??= <Map<String, dynamic>>[]).add(row);
      }

      final slots = <String>{};
      for (final row in mealDays) {
        final raw = row['meal_slot'];
        final slot = raw is String ? raw.trim() : '';
        if (slot.isNotEmpty) slots.add(slot);
      }

      // legacy meal_slot -> 标签（tool_tags.category_id = meal_slot）
      const toolId = 'overcooked_kitchen';
      const categoryId = 'meal_slot';
      final now = DateTime.now().millisecondsSinceEpoch;

      String slotToName(String slot) {
        switch (slot) {
          case 'mid_lunch':
            return '中班午餐';
          case 'mid_dinner':
            return '中班晚餐';
          default:
            return slot;
        }
      }

      Future<int> ensureSlotTag(String slot) async {
        final name = slotToName(slot);
        final existing = await txn.query(
          'tags',
          columns: const ['id'],
          where: 'name = ?',
          whereArgs: [name],
          limit: 1,
        );
        int tagId;
        if (existing.isNotEmpty) {
          tagId = existing.single['id'] as int;
        } else {
          final maxRows = await txn.rawQuery(
            'SELECT MAX(sort_index) AS max_sort_index FROM tags',
          );
          final maxSortIndex = (maxRows.first['max_sort_index'] as int?) ?? -1;
          tagId = await txn.insert('tags', {
            'name': name,
            'color': null,
            'sort_index': maxSortIndex + 1,
            'created_at': now,
            'updated_at': now,
          });
        }

        final maxLinkRows = await txn.rawQuery(
          '''
SELECT MAX(sort_index) AS max_sort_index
FROM tool_tags
WHERE tool_id = ? AND category_id = ?
''',
          [toolId, categoryId],
        );
        final maxLinkSortIndex =
            (maxLinkRows.first['max_sort_index'] as int?) ?? -1;

        await txn.insert('tool_tags', {
          'tool_id': toolId,
          'tag_id': tagId,
          'category_id': categoryId,
          'sort_index': maxLinkSortIndex + 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
        return tagId;
      }

      final slotTagIdBySlot = <String, int>{};
      for (final slot in slots) {
        slotTagIdBySlot[slot] = await ensureSlotTag(slot);
      }

      for (final row in mealDays) {
        final dayKey = row['day_key'];
        if (dayKey is! int) continue;
        final note = (row['note'] as String?) ?? '';
        final rawSlot = row['meal_slot'];
        final slot = rawSlot is String ? rawSlot.trim() : '';
        final mealTagId = slot.isEmpty ? null : slotTagIdBySlot[slot];
        final createdAt = (row['created_at'] as int?) ?? now;
        final updatedAt = (row['updated_at'] as int?) ?? now;

        final mealId = await txn.insert('overcooked_meals', {
          'id': row['day_key'], // legacy: day_key 唯一，直接复用为 id，避免 meal_items 失配
          'day_key': dayKey,
          'meal_tag_id': mealTagId,
          'note': note,
          'sort_index': 0,
          'created_at': createdAt,
          'updated_at': updatedAt,
        });

        final items = (itemsByDayKey[dayKey] ?? const <Map<String, dynamic>>[])
          ..sort((a, b) {
            final ca = (a['created_at'] as int?) ?? 0;
            final cb = (b['created_at'] as int?) ?? 0;
            if (ca != cb) return ca.compareTo(cb);
            return (a['recipe_id'] as int).compareTo(b['recipe_id'] as int);
          });

        for (int i = 0; i < items.length; i++) {
          final it = items[i];
          await txn.insert('overcooked_meal_items', {
            'meal_id': mealId,
            'recipe_id': it['recipe_id'] as int,
            'sort_index': i,
            'created_at': (it['created_at'] as int?) ?? now,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
      }
    });
  }

  static Future<int?> _findMealId(
    DatabaseExecutor db, {
    required int dayKey,
    required int? mealTagId,
  }) async {
    if (mealTagId == null) {
      final rows = await db.query(
        'overcooked_meals',
        columns: const ['id'],
        where: 'day_key = ? AND meal_tag_id IS NULL',
        whereArgs: [dayKey],
        limit: 1,
      );
      return rows.isEmpty ? null : (rows.single['id'] as int);
    }
    final rows = await db.query(
      'overcooked_meals',
      columns: const ['id'],
      where: 'day_key = ? AND meal_tag_id = ?',
      whereArgs: [dayKey, mealTagId],
      limit: 1,
    );
    return rows.isEmpty ? null : (rows.single['id'] as int);
  }

  static Future<int> _nextMealSortIndex(
    DatabaseExecutor db, {
    required int dayKey,
  }) async {
    final rows = await db.rawQuery(
      'SELECT MAX(sort_index) AS max_sort_index FROM overcooked_meals WHERE day_key = ?',
      [dayKey],
    );
    final maxSortIndex = (rows.first['max_sort_index'] as int?) ?? -1;
    return maxSortIndex + 1;
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
    final placeholders = _placeholders(ids.length);
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

  // ==================== 打分相关 ====================

  Future<void> upsertRating({
    required int mealId,
    required int recipeId,
    required int rating,
    DateTime? now,
  }) async {
    final db = await _database;
    await db.insert('overcooked_meal_item_ratings', {
      'meal_id': mealId,
      'recipe_id': recipeId,
      'rating': rating,
      'created_at': (now ?? DateTime.now()).millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteRating({
    required int mealId,
    required int recipeId,
  }) async {
    final db = await _database;
    await db.delete(
      'overcooked_meal_item_ratings',
      where: 'meal_id = ? AND recipe_id = ?',
      whereArgs: [mealId, recipeId],
    );
  }

  Future<Map<int, int>> getRatingsForMeal(int mealId) async {
    final db = await _database;
    final rows = await db.query(
      'overcooked_meal_item_ratings',
      columns: const ['recipe_id', 'rating'],
      where: 'meal_id = ?',
      whereArgs: [mealId],
    );
    return {
      for (final row in rows) row['recipe_id'] as int: row['rating'] as int,
    };
  }

  /// 获取所有菜谱的统计数据：做菜次数和平均分
  Future<Map<int, ({int cookCount, double avgRating, int ratingCount})>>
  getRecipeStats() async {
    final db = await _database;

    // 统计每个菜谱的做菜次数
    final cookCountRows = await db.rawQuery('''
SELECT recipe_id, COUNT(*) AS cook_count
FROM overcooked_meal_items
GROUP BY recipe_id
''');
    final cookCounts = <int, int>{
      for (final row in cookCountRows)
        row['recipe_id'] as int: row['cook_count'] as int,
    };

    // 统计每个菜谱的评分
    final ratingRows = await db.rawQuery('''
SELECT recipe_id, SUM(rating) AS total_rating, COUNT(*) AS rating_count
FROM overcooked_meal_item_ratings
GROUP BY recipe_id
''');

    final result =
        <int, ({int cookCount, double avgRating, int ratingCount})>{};

    // 合并数据
    final allRecipeIds = <int>{...cookCounts.keys};
    for (final row in ratingRows) {
      allRecipeIds.add(row['recipe_id'] as int);
    }

    for (final recipeId in allRecipeIds) {
      final cookCount = cookCounts[recipeId] ?? 0;
      final ratingRow = ratingRows.firstWhere(
        (r) => r['recipe_id'] == recipeId,
        orElse: () => <String, Object?>{},
      );
      final totalRating = (ratingRow['total_rating'] as int?) ?? 0;
      final ratingCount = (ratingRow['rating_count'] as int?) ?? 0;
      final avgRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;

      result[recipeId] = (
        cookCount: cookCount,
        avgRating: avgRating,
        ratingCount: ratingCount,
      );
    }

    return result;
  }

  /// 获取单个菜谱的统计数据
  Future<({int cookCount, double avgRating, int ratingCount})> getRecipeStat(
    int recipeId,
  ) async {
    final db = await _database;

    final cookCountRows = await db.rawQuery(
      '''
SELECT COUNT(*) AS cook_count
FROM overcooked_meal_items
WHERE recipe_id = ?
''',
      [recipeId],
    );
    final cookCount = (cookCountRows.first['cook_count'] as int?) ?? 0;

    final ratingRows = await db.rawQuery(
      '''
SELECT SUM(rating) AS total_rating, COUNT(*) AS rating_count
FROM overcooked_meal_item_ratings
WHERE recipe_id = ?
''',
      [recipeId],
    );
    final totalRating = (ratingRows.first['total_rating'] as int?) ?? 0;
    final ratingCount = (ratingRows.first['rating_count'] as int?) ?? 0;
    final avgRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;

    return (
      cookCount: cookCount,
      avgRating: avgRating,
      ratingCount: ratingCount,
    );
  }
}
