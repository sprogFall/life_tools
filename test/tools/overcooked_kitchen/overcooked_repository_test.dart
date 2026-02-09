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
      final typeId = await tagRepository.createTagForToolCategory(
        name: '家常菜',
        toolId: 'overcooked_kitchen',
        categoryId: 'dish_type',
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );
      final ingredientId = await tagRepository.createTagForToolCategory(
        name: '鸡腿肉',
        toolId: 'overcooked_kitchen',
        categoryId: 'ingredient',
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );
      final sauceId = await tagRepository.createTagForToolCategory(
        name: '生抽',
        toolId: 'overcooked_kitchen',
        categoryId: 'sauce',
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

    test('可按风格统计菜品数量', () async {
      final typeA = await tagRepository.createTagForToolCategory(
        name: '主菜',
        toolId: 'overcooked_kitchen',
        categoryId: 'dish_type',
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );
      final typeB = await tagRepository.createTagForToolCategory(
        name: '汤',
        toolId: 'overcooked_kitchen',
        categoryId: 'dish_type',
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );
      final typeC = await tagRepository.createTagForToolCategory(
        name: '甜品',
        toolId: 'overcooked_kitchen',
        categoryId: 'dish_type',
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );

      final now = DateTime(2026, 1, 2, 10);
      await repository.createRecipe(
        OvercookedRecipe.create(
          name: '红烧肉',
          coverImageKey: null,
          typeTagId: typeA,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '',
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );
      await repository.createRecipe(
        OvercookedRecipe.create(
          name: '鱼香肉丝',
          coverImageKey: null,
          typeTagId: typeA,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '',
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );
      await repository.createRecipe(
        OvercookedRecipe.create(
          name: '紫菜蛋花汤',
          coverImageKey: null,
          typeTagId: typeB,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '',
          content: '',
          detailImageKeys: const [],
          now: now,
        ),
      );
      await repository.createRecipe(
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

      final counts = await repository.countRecipesByTypeTagIds([
        typeA,
        typeB,
        typeC,
        9999,
      ]);

      expect(counts[typeA], 2);
      expect(counts[typeB], 1);
      expect(counts.containsKey(typeC), isFalse);
      expect(counts.containsKey(9999), isFalse);
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

    test('三餐记录：餐次用标签区分，评价跟随餐次，并可用愿望单导入', () async {
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

      final c = await repository.createRecipe(
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

      final day = DateTime(2026, 1, 10, 12);
      await repository.addWish(date: day, recipeId: a, now: now);
      await repository.addWish(date: day, recipeId: b, now: now);

      final breakfastTagId = await tagRepository.createTagForToolCategory(
        name: '早餐',
        toolId: 'overcooked_kitchen',
        categoryId: 'meal_slot',
        now: now,
      );
      final dinnerTagId = await tagRepository.createTagForToolCategory(
        name: '晚餐',
        toolId: 'overcooked_kitchen',
        categoryId: 'meal_slot',
        now: now,
      );

      await repository.replaceMealWithWishes(
        date: day,
        mealTagId: dinnerTagId,
        now: now,
      );
      await repository.upsertMealNote(
        date: day,
        mealTagId: dinnerTagId,
        note: '晚餐好吃！',
        now: now,
      );

      await repository.replaceMeal(
        date: day,
        mealTagId: breakfastTagId,
        recipeIds: [c],
        now: now,
      );
      await repository.upsertMealNote(
        date: day,
        mealTagId: breakfastTagId,
        note: '早餐一般',
        now: now,
      );

      final meals = await repository.listMealsForDate(day);
      expect(meals.length, 2);
      final byTag = {for (final m in meals) m.mealTagId: m};
      expect(byTag[breakfastTagId]!.note, '早餐一般');
      expect(byTag[breakfastTagId]!.recipeIds, [c]);
      expect(byTag[dinnerTagId]!.note, '晚餐好吃！');
      expect(byTag[dinnerTagId]!.recipeIds.toSet(), {a, b});
    });

    test('厨房日历：按“类型去重”的每日做菜量统计', () async {
      final t1 = await tagRepository.createTagForToolCategory(
        name: '快手菜',
        toolId: 'overcooked_kitchen',
        categoryId: 'dish_type',
        color: null,
        now: DateTime(2026, 1, 1, 9),
      );
      final t2 = await tagRepository.createTagForToolCategory(
        name: '汤',
        toolId: 'overcooked_kitchen',
        categoryId: 'dish_type',
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
      final breakfast = await tagRepository.createTagForToolCategory(
        name: '早餐',
        toolId: 'overcooked_kitchen',
        categoryId: 'meal_slot',
        now: now,
      );
      final dinner = await tagRepository.createTagForToolCategory(
        name: '晚餐',
        toolId: 'overcooked_kitchen',
        categoryId: 'meal_slot',
        now: now,
      );
      await repository.replaceMeal(
        date: day,
        mealTagId: breakfast,
        recipeIds: [a, b],
        now: now,
      );
      await repository.replaceMeal(
        date: day,
        mealTagId: dinner,
        recipeIds: [c],
        now: now,
      );

      final stats = await repository.getMonthlyCookCountsByTypeDistinct(
        year: 2026,
        month: 1,
      );

      final key = OvercookedRepository.dayKey(day);
      expect(stats[key], 3); // a, b, c 三个菜谱
    });

    test('厨房日历：可读取本月最近做的菜并按日期倒序', () async {
      final now = DateTime(2026, 1, 2, 10);
      final a = await repository.createRecipe(
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
      final b = await repository.createRecipe(
        OvercookedRecipe.create(
          name: '红烧肉',
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
      final c = await repository.createRecipe(
        OvercookedRecipe.create(
          name: '冬瓜汤',
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

      await repository.replaceMeal(
        date: DateTime(2026, 1, 5),
        recipeIds: [a],
        now: now,
      );
      await repository.replaceMeal(
        date: DateTime(2026, 1, 8),
        recipeIds: [a],
        now: now,
      );
      await repository.replaceMeal(
        date: DateTime(2026, 1, 9),
        recipeIds: [b],
        now: now,
      );
      await repository.replaceMeal(
        date: DateTime(2026, 2, 1),
        recipeIds: [c],
        now: now,
      );

      final recent = await repository.listRecentCookedRecipesForMonth(
        year: 2026,
        month: 1,
      );

      expect(recent.length, 2);
      expect(recent[0].recipe.id, b);
      expect(recent[0].recipe.name, '红烧肉');
      expect(recent[0].cookedDate, DateTime(2026, 1, 9));
      expect(recent[0].cookCount, 1);
      expect(recent[1].recipe.id, a);
      expect(recent[1].recipe.name, '番茄炒蛋');
      expect(recent[1].cookedDate, DateTime(2026, 1, 8));
      expect(recent[1].cookCount, 2);

      final limited = await repository.listRecentCookedRecipesForMonth(
        year: 2026,
        month: 1,
        limit: 1,
      );
      expect(limited.length, 1);
      expect(limited.single.recipe.id, b);
    });
  });
}
