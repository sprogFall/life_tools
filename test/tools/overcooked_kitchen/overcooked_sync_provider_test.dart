import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
import 'package:life_tools/tools/overcooked_kitchen/sync/overcooked_sync_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('OvercookedSyncProvider', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('同步快照应包含并可恢复菜谱打分', () async {
      final db1 = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      final repo1 = OvercookedRepository.withDatabase(db1);

      final now = DateTime(2026, 1, 1, 10);
      final recipeId = await repo1.createRecipe(
        OvercookedRecipe.create(
          name: '番茄炒蛋',
          coverImageKey: null,
          typeTagId: null,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '',
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );

      final day = DateTime(2026, 1, 2, 12);
      await repo1.replaceMeal(date: day, recipeIds: [recipeId], now: now);
      final mealId = (await repo1.listMealsForDate(day)).single.id!;
      await repo1.upsertRating(
        mealId: mealId,
        recipeId: recipeId,
        rating: 5,
        now: now,
      );

      final provider1 = OvercookedSyncProvider(repository: repo1);
      final exported = await provider1.exportData();
      final data = exported['data'] as Map<String, dynamic>;

      expect(data.containsKey('meal_item_ratings'), isTrue);
      expect((data['meal_item_ratings'] as List).length, 1);

      final db2 = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      addTearDown(() async {
        await db1.close();
        await db2.close();
      });

      final repo2 = OvercookedRepository.withDatabase(db2);
      final provider2 = OvercookedSyncProvider(repository: repo2);
      await provider2.importData(Map<String, dynamic>.from(exported));

      final restored = await repo2.getRatingsForMeal(mealId);
      expect(restored[recipeId], 5);
    });

    test('导入时应清理旧打分（即使 foreign_keys 关闭）', () async {
      final db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      addTearDown(() async => db.close());

      final repo = OvercookedRepository.withDatabase(db);
      final now = DateTime(2026, 1, 1, 10);
      final recipeId = await repo.createRecipe(
        OvercookedRecipe.create(
          name: '麻婆豆腐',
          coverImageKey: null,
          typeTagId: null,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '',
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );

      final day = DateTime(2026, 1, 2, 12);
      await repo.replaceMeal(date: day, recipeIds: [recipeId], now: now);
      final mealId = (await repo.listMealsForDate(day)).single.id!;
      await repo.upsertRating(
        mealId: mealId,
        recipeId: recipeId,
        rating: 3,
        now: now,
      );

      await db.execute('PRAGMA foreign_keys = OFF');

      final provider = OvercookedSyncProvider(repository: repo);
      await provider.importData({'version': 3, 'data': const <String, dynamic>{}});

      final rows = await db.query('overcooked_meal_item_ratings');
      expect(rows, isEmpty);
    });
  });
}
