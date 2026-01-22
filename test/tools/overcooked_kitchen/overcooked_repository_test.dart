import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('OvercookedRepository', () {
    late Database db;
    late OvercookedRepository repository;
    late TagRepository tagRepository;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      repository = OvercookedRepository.withDatabase(db);
      tagRepository = TagRepository.withDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('可以创建并读取菜谱（含标签与口味）', () async {
      final typeId = await tagRepository.createTag(
        name: '家常菜',
        toolIds: const ['overcooked_kitchen'],
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );
      final ingredientId = await tagRepository.createTag(
        name: '鸡腿肉',
        toolIds: const ['overcooked_kitchen'],
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );
      final sauceId = await tagRepository.createTag(
        name: '生抽',
        toolIds: const ['overcooked_kitchen'],
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );
      final spicyId = await tagRepository.createTagForToolCategory(
        name: '辣',
        toolId: 'overcooked_kitchen',
        categoryId: 'flavor',
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );
      final sweetId = await tagRepository.createTagForToolCategory(
        name: '甜',
        toolId: 'overcooked_kitchen',
        categoryId: 'flavor',
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );

      final now = DateTime(2026, 1, 2, 10);
      final id = await repository.createRecipe(
        OvercookedRecipe.create(
          name: '宫保鸡丁',
          coverImageKey: 'media/cover.jpg',
          typeTagId: typeId,
          ingredientTagIds: [ingredientId],
          sauceTagIds: [sauceId],
          flavorTagIds: [spicyId, sweetId],
          intro: '下饭神器',
          content: '步骤略',
          detailImageKeys: const ['media/detail1.jpg', 'media/detail2.jpg'],
          now: now,
        ),
      );

      final recipe = await repository.getRecipe(id);
      expect(recipe, isNotNull);
      expect(recipe!.name, '宫保鸡丁');
      expect(recipe.typeTagId, typeId);
      expect(recipe.ingredientTagIds, [ingredientId]);
      expect(recipe.sauceTagIds, [sauceId]);
      expect(recipe.flavorTagIds.toSet(), {spicyId, sweetId});
      expect(recipe.detailImageKeys.length, 2);
      expect(recipe.createdAt, now);
    });

    test('愿望单：同一天同菜谱去重，并可查询', () async {
      final now = DateTime(2026, 1, 2, 10);
      final recipeId = await repository.createRecipe(
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

      final day = DateTime(2026, 1, 10, 12, 30);
      await repository.addWish(date: day, recipeId: recipeId, now: now);
      await repository.addWish(date: day, recipeId: recipeId, now: now);

      final wishes = await repository.listWishesForDate(day);
      expect(wishes.length, 1);
      expect(wishes.single.recipeId, recipeId);
    });

    test('三餐记录：可用愿望单覆盖，并支持当天评价', () async {
      final now = DateTime(2026, 1, 2, 10);
      final a = await repository.createRecipe(
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
      final b = await repository.createRecipe(
        OvercookedRecipe.create(
          name: '可乐鸡翅',
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

      final day = DateTime(2026, 1, 10, 12);
      await repository.addWish(date: day, recipeId: a, now: now);
      await repository.addWish(date: day, recipeId: b, now: now);

      await repository.replaceMealWithWishes(date: day, now: now);
      await repository.upsertMealNote(
        date: day,
        note: '好吃！',
        mealSlot: 'mid_lunch',
        now: now,
      );

      final meal = await repository.getMealForDate(day);
      expect(meal, isNotNull);
      expect(meal!.recipeIds, containsAll([a, b]));
      expect(meal.note, '好吃！');
      expect(meal.mealSlot, 'mid_lunch');
    });

    test('厨房日历：按“类型去重”的每日做菜量统计', () async {
      final t1 = await tagRepository.createTag(
        name: '快手菜',
        toolIds: const ['overcooked_kitchen'],
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );
      final t2 = await tagRepository.createTag(
        name: '汤',
        toolIds: const ['overcooked_kitchen'],
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );

      final now = DateTime(2026, 1, 2, 10);
      final a = await repository.createRecipe(
        OvercookedRecipe.create(
          name: '青椒肉丝',
          coverImageKey: null,
          typeTagId: t1,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '',
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );
      final b = await repository.createRecipe(
        OvercookedRecipe.create(
          name: '鱼香肉丝',
          coverImageKey: null,
          typeTagId: t1,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '',
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );
      final c = await repository.createRecipe(
        OvercookedRecipe.create(
          name: '冬瓜排骨汤',
          coverImageKey: null,
          typeTagId: t2,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '',
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );

      final day = DateTime(2026, 1, 10, 12);
      await repository.replaceMeal(date: day, recipeIds: [a, b, c], now: now);

      final stats = await repository.getMonthlyCookCountsByTypeDistinct(
        year: 2026,
        month: 1,
      );

      final key = OvercookedRepository.dayKey(day);
      expect(stats[key], 2);
    });
  });
}
