import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/obj_store_service.dart';
import 'package:life_tools/core/obj_store/qiniu/qiniu_client.dart';
import 'package:life_tools/core/obj_store/secret_store/in_memory_secret_store.dart';
import 'package:life_tools/core/obj_store/storage/local_obj_store.dart';
import 'package:life_tools/core/tags/models/tag.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_meal.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_wish_item.dart';
import 'package:life_tools/tools/overcooked_kitchen/overcooked_constants.dart';
import 'package:life_tools/tools/overcooked_kitchen/pages/recipe/overcooked_recipe_detail_page.dart';
import 'package:life_tools/tools/overcooked_kitchen/pages/recipe/overcooked_recipe_edit_page.dart';
import 'package:life_tools/tools/overcooked_kitchen/pages/tabs/overcooked_meal_tab.dart';
import 'package:life_tools/tools/overcooked_kitchen/pages/tabs/overcooked_wishlist_tab.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_helpers/test_app_wrapper.dart';

class _FakeDatabase extends Fake implements Database {}

class _NoopObjStoreService extends ObjStoreService {
  _NoopObjStoreService()
    : super(
        configService: ObjStoreConfigService(
          secretStore: InMemorySecretStore(),
        ),
        localStore: LocalObjStore(
          baseDirProvider: () async {
            final dir = Directory(
              '${Directory.systemTemp.path}/noop_obj_store',
            );
            if (!dir.existsSync()) dir.createSync(recursive: true);
            return dir;
          },
        ),
        qiniuClient: QiniuClient(),
      );
}

class _BlockingTagService extends TagService {
  final List<String> calledCategories = [];
  final Map<String, Completer<List<Tag>>> _completers =
      <String, Completer<List<Tag>>>{};

  _BlockingTagService()
    : super(repository: TagRepository.withDatabase(_FakeDatabase()));

  @override
  Future<List<Tag>> listTagsForToolCategory({
    required String toolId,
    required String categoryId,
    bool refresh = true,
  }) {
    calledCategories.add(categoryId);
    return _completers
        .putIfAbsent(categoryId, () => Completer<List<Tag>>())
        .future;
  }

  @override
  Future<List<Tag>> listTagsForTool(String toolId) async {
    return const [];
  }

  void completeAll() {
    for (final completer in _completers.values) {
      if (!completer.isCompleted) {
        completer.complete(const []);
      }
    }
  }
}

class _ImmediateTagService extends TagService {
  _ImmediateTagService()
    : super(repository: TagRepository.withDatabase(_FakeDatabase()));

  @override
  Future<List<Tag>> listTagsForToolCategory({
    required String toolId,
    required String categoryId,
    bool refresh = true,
  }) async {
    return const [];
  }

  @override
  Future<List<Tag>> listTagsForTool(String toolId) async {
    return const [];
  }
}

class _WishlistRepo extends OvercookedRepository {
  _WishlistRepo() : super.withDatabase(_FakeDatabase());

  @override
  Future<List<OvercookedWishItem>> listWishesForDate(DateTime date) async {
    return [
      OvercookedWishItem(
        id: 1,
        dayKey: OvercookedRepository.dayKey(date),
        recipeId: 100,
        createdAt: DateTime(2026, 1, 1, 10),
      ),
    ];
  }

  @override
  Future<List<OvercookedRecipe>> listRecipesByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    return [
      OvercookedRecipe.create(
        name: '清炒时蔬',
        coverImageKey: null,
        typeTagId: null,
        ingredientTagIds: const [],
        sauceTagIds: const [],
        flavorTagIds: const [],
        intro: '',
        content: '',
        detailImageKeys: const [],
        now: DateTime(2026, 1, 1, 10),
      ).copyWith(id: 100),
    ];
  }
}

class _DetailRepo extends OvercookedRepository {
  _DetailRepo() : super.withDatabase(_FakeDatabase());

  @override
  Future<OvercookedRecipe?> getRecipe(int id) async {
    return OvercookedRecipe.create(
      name: '土豆炖牛腩',
      coverImageKey: null,
      typeTagId: null,
      ingredientTagIds: const [],
      sauceTagIds: const [],
      flavorTagIds: const [],
      intro: '',
      content: '',
      detailImageKeys: const [],
      now: DateTime(2026, 1, 1, 10),
    ).copyWith(id: id);
  }
}

class _MealRatingsRepo extends OvercookedRepository {
  final List<int> ratingRequestMealIds = <int>[];
  final Map<int, Completer<Map<int, int>>> _ratingCompleters =
      <int, Completer<Map<int, int>>>{
        1: Completer<Map<int, int>>(),
        2: Completer<Map<int, int>>(),
        3: Completer<Map<int, int>>(),
      };

  _MealRatingsRepo() : super.withDatabase(_FakeDatabase());

  @override
  Future<List<OvercookedMeal>> listMealsForDate(DateTime date) async {
    final dayKey = OvercookedRepository.dayKey(date);
    return [
      OvercookedMeal(
        id: 1,
        dayKey: dayKey,
        mealTagId: 11,
        note: '',
        sortIndex: 0,
        recipeIds: const [101],
      ),
      OvercookedMeal(
        id: 2,
        dayKey: dayKey,
        mealTagId: 12,
        note: '',
        sortIndex: 1,
        recipeIds: const [102],
      ),
      OvercookedMeal(
        id: 3,
        dayKey: dayKey,
        mealTagId: 13,
        note: '',
        sortIndex: 2,
        recipeIds: const [103],
      ),
    ];
  }

  @override
  Future<List<OvercookedRecipe>> listRecipesByIds(List<int> ids) async {
    return const [];
  }

  @override
  Future<Map<int, int>> getRatingsForMeal(int mealId) {
    ratingRequestMealIds.add(mealId);
    return _ratingCompleters
        .putIfAbsent(mealId, () => Completer<Map<int, int>>())
        .future;
  }

  void completeAllRatings() {
    for (final completer in _ratingCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete(const <int, int>{});
      }
    }
  }
}

Widget _wrapWithProviders({
  required OvercookedRepository repository,
  required TagService tagService,
  required ObjStoreService objStoreService,
  required Widget child,
}) {
  return MultiProvider(
    providers: [
      Provider<OvercookedRepository>.value(value: repository),
      ChangeNotifierProvider<TagService>.value(value: tagService),
      Provider<ObjStoreService>.value(value: objStoreService),
    ],
    child: TestAppWrapper(child: child),
  );
}

Future<void> _pumpAsyncTicks(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

void main() {
  group('Overcooked 异步加载性能（并行化）', () {
    testWidgets('愿望单刷新应并行触发食材/调味标签查询', (tester) async {
      final tagService = _BlockingTagService();

      await tester.pumpWidget(
        _wrapWithProviders(
          repository: _WishlistRepo(),
          tagService: tagService,
          objStoreService: _NoopObjStoreService(),
          child: OvercookedWishlistTab(
            date: DateTime(2026, 1, 10),
            onDateChanged: (_) {},
            onWishesChanged: () {},
          ),
        ),
      );

      await _pumpAsyncTicks(tester);

      expect(
        tagService.calledCategories,
        containsAll([
          OvercookedTagCategories.ingredient,
          OvercookedTagCategories.sauce,
        ]),
      );
      expect(tagService.calledCategories.length, 2);

      tagService.completeAll();
      await tester.pump();
    });

    testWidgets('菜谱详情加载应并行触发四类标签查询', (tester) async {
      final tagService = _BlockingTagService();

      await tester.pumpWidget(
        _wrapWithProviders(
          repository: _DetailRepo(),
          tagService: tagService,
          objStoreService: _NoopObjStoreService(),
          child: const OvercookedRecipeDetailPage(recipeId: 7),
        ),
      );

      await _pumpAsyncTicks(tester);

      expect(
        tagService.calledCategories,
        containsAll([
          OvercookedTagCategories.dishType,
          OvercookedTagCategories.ingredient,
          OvercookedTagCategories.sauce,
          OvercookedTagCategories.flavor,
        ]),
      );
      expect(tagService.calledCategories.length, 4);

      tagService.completeAll();
      await tester.pump();
    });

    testWidgets('菜谱编辑页加载应并行触发四类标签查询', (tester) async {
      final tagService = _BlockingTagService();

      await tester.pumpWidget(
        _wrapWithProviders(
          repository: _DetailRepo(),
          tagService: tagService,
          objStoreService: _NoopObjStoreService(),
          child: const OvercookedRecipeEditPage(),
        ),
      );

      await _pumpAsyncTicks(tester);

      expect(
        tagService.calledCategories,
        containsAll([
          OvercookedTagCategories.dishType,
          OvercookedTagCategories.ingredient,
          OvercookedTagCategories.sauce,
          OvercookedTagCategories.flavor,
        ]),
      );
      expect(tagService.calledCategories.length, 4);

      tagService.completeAll();
      await tester.pump();
    });

    testWidgets('三餐页刷新应并行触发每个餐次评分查询', (tester) async {
      final repo = _MealRatingsRepo();

      await tester.pumpWidget(
        _wrapWithProviders(
          repository: repo,
          tagService: _ImmediateTagService(),
          objStoreService: _NoopObjStoreService(),
          child: OvercookedMealTab(
            date: DateTime(2026, 1, 10),
            onDateChanged: (_) {},
          ),
        ),
      );

      await _pumpAsyncTicks(tester);

      expect(repo.ratingRequestMealIds, containsAll([1, 2, 3]));
      expect(repo.ratingRequestMealIds.length, 3);

      repo.completeAllRatings();
      await tester.pump();
    });
  });
}
