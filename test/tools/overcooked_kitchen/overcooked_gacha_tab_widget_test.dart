import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/obj_store_service.dart';
import 'package:life_tools/core/obj_store/qiniu/qiniu_client.dart';
import 'package:life_tools/core/obj_store/secret_store/in_memory_secret_store.dart';
import 'package:life_tools/core/obj_store/storage/local_obj_store.dart';
import 'package:life_tools/core/tags/models/tag.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/pages/tabs/overcooked_gacha_tab.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_helpers/test_app_wrapper.dart';

class _FakeTagService extends TagService {
  final List<Tag> _tags;

  _FakeTagService(Database db, {required List<Tag> tags})
    : _tags = tags,
      super(repository: TagRepository.withDatabase(db));

  @override
  Future<List<Tag>> listTagsForToolCategory({
    required String toolId,
    required String categoryId,
    bool refresh = true,
  }) async {
    return _tags;
  }
}

class _FakeOvercookedRepository extends OvercookedRepository {
  final List<OvercookedRecipe> recipes;
  final Map<int, ({int cookCount, double avgRating, int ratingCount})>
  recipeStats;
  final List<({DateTime date, int recipeId})> addedWishes = [];

  // ignore: use_super_parameters
  _FakeOvercookedRepository(
    Database db, {
    required this.recipes,
    this.recipeStats = const {},
  }) : super.withDatabase(db);

  @override
  Future<List<OvercookedRecipe>> listRecipesByTypeTagIds(
    List<int> typeTagIds,
  ) async {
    final set = typeTagIds.toSet();
    return recipes
        .where((r) => r.typeTagId != null && set.contains(r.typeTagId))
        .toList();
  }

  @override
  Future<Map<int, int>> countRecipesByTypeTagIds(List<int> typeTagIds) async {
    final map = <int, int>{};
    final set = typeTagIds.toSet();
    for (final recipe in recipes) {
      final typeId = recipe.typeTagId;
      if (typeId == null || !set.contains(typeId)) continue;
      map[typeId] = (map[typeId] ?? 0) + 1;
    }
    return map;
  }

  @override
  Future<void> addWish({
    required DateTime date,
    required int recipeId,
    DateTime? now,
  }) async {
    addedWishes.add((
      date: DateTime(date.year, date.month, date.day),
      recipeId: recipeId,
    ));
  }

  @override
  Future<Map<int, ({int cookCount, double avgRating, int ratingCount})>>
  getRecipeStats() async {
    return recipeStats;
  }
}

class _CountingObjStoreService extends ObjStoreService {
  int getCachedFileCallCount = 0;
  int ensureCachedFileCallCount = 0;

  _CountingObjStoreService()
    : super(
        configService: ObjStoreConfigService(
          secretStore: InMemorySecretStore(),
        ),
        localStore: LocalObjStore(
          baseDirProvider: () async {
            final dir = Directory(
              p.join(Directory.systemTemp.path, 'gacha_cache_test'),
            );
            if (!dir.existsSync()) dir.createSync(recursive: true);
            return dir;
          },
        ),
        qiniuClient: QiniuClient(),
      );

  @override
  Future<File?> getCachedFile({required String key}) async {
    getCachedFileCallCount++;
    return null;
  }

  @override
  Future<File?> ensureCachedFile({
    required String key,
    Duration timeout = const Duration(seconds: 12),
    Future<String> Function()? resolveUriWhenMiss,
  }) async {
    ensureCachedFileCallCount++;
    return null;
  }
}

void main() {
  group('OvercookedGachaTab（Widget）', () {
    late Database db;
    late TagService tagService;
    late OvercookedRepository repository;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('未选择搭配时“扭蛋”按钮不可按；选择后可按并出现“就你了”', (tester) async {
      final now = DateTime(2026, 1, 2, 10);
      final typeTag = Tag(
        id: 1,
        name: '主菜',
        color: null,
        sortIndex: 0,
        createdAt: now,
        updatedAt: now,
      );
      tagService = _FakeTagService(db, tags: [typeTag]);
      repository = _FakeOvercookedRepository(
        db,
        recipes: [
          OvercookedRecipe.create(
            name: '红烧肉',
            coverImageKey: null,
            typeTagId: typeTag.id,
            ingredientTagIds: const [],
            sauceTagIds: const [],
            flavorTagIds: const [],
            intro: '',
            content: '',
            detailImageKeys: const [],
            now: now,
          ).copyWith(id: 100),
        ],
      );

      DateTime? importedDate;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<OvercookedRepository>.value(value: repository),
          ],
          child: TestAppWrapper(
            child: OvercookedGachaTab(
              targetDate: DateTime(2026, 1, 2),
              onTargetDateChanged: (_) {},
              onImportToWish: (d) => importedDate = d,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rollButton = tester.widget<CupertinoButton>(
        find.byKey(const ValueKey('overcooked_gacha_roll_button')),
      );
      expect(rollButton.onPressed, isNull);
      expect(find.text('扭蛋'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_pick_types_button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('主菜'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      final rollButtonAfterPick = tester.widget<CupertinoButton>(
        find.byKey(const ValueKey('overcooked_gacha_roll_button')),
      );
      expect(rollButtonAfterPick.onPressed, isNotNull);

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_roll_button')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('overcooked_gacha_import_button')),
        findsOneWidget,
      );
      expect(find.text('就你了'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_import_button')),
      );
      await tester.pumpAndSettle();

      expect(importedDate, DateTime(2026, 1, 2));
      expect((repository as _FakeOvercookedRepository).addedWishes, [
        (date: DateTime(2026, 1, 2), recipeId: 100),
      ]);
    });

    testWidgets('点击扭蛋后应出现抽卡浮层与按钮爆炸粒子', (tester) async {
      final now = DateTime(2026, 1, 2, 10);
      final typeTag = Tag(
        id: 1,
        name: '主菜',
        color: null,
        sortIndex: 0,
        createdAt: now,
        updatedAt: now,
      );
      tagService = _FakeTagService(db, tags: [typeTag]);
      repository = _FakeOvercookedRepository(
        db,
        recipes: [
          OvercookedRecipe.create(
            name: '红烧肉',
            coverImageKey: null,
            typeTagId: typeTag.id,
            ingredientTagIds: const [],
            sauceTagIds: const [],
            flavorTagIds: const [],
            intro: '',
            content: '',
            detailImageKeys: const [],
            now: now,
          ).copyWith(id: 100),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<OvercookedRepository>.value(value: repository),
          ],
          child: TestAppWrapper(
            child: OvercookedGachaTab(
              targetDate: DateTime(2026, 1, 2),
              onTargetDateChanged: (_) {},
              onImportToWish: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_pick_types_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('主菜'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_roll_button')),
      );
      await tester.pump(const Duration(milliseconds: 80));

      expect(
        find.byKey(const ValueKey('overcooked_gacha_draw_overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('overcooked_gacha_draw_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('overcooked_gacha_draw_card_highlight')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('overcooked_gacha_roll_particle_burst')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('抽卡浮层图片应优先读取缓存，不触发下载', (tester) async {
      final now = DateTime(2026, 1, 2, 10);
      final typeTag = Tag(
        id: 1,
        name: '主菜',
        color: null,
        sortIndex: 0,
        createdAt: now,
        updatedAt: now,
      );
      tagService = _FakeTagService(db, tags: [typeTag]);
      repository = _FakeOvercookedRepository(
        db,
        recipes: [
          OvercookedRecipe.create(
            name: '红烧肉',
            coverImageKey: 'images/r1.jpg',
            typeTagId: typeTag.id,
            ingredientTagIds: const [],
            sauceTagIds: const [],
            flavorTagIds: const [],
            intro: '',
            content: '',
            detailImageKeys: const [],
            now: now,
          ).copyWith(id: 100),
        ],
      );
      final objStoreService = _CountingObjStoreService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<OvercookedRepository>.value(value: repository),
            Provider<ObjStoreService>.value(value: objStoreService),
          ],
          child: TestAppWrapper(
            child: OvercookedGachaTab(
              targetDate: DateTime(2026, 1, 2),
              onTargetDateChanged: (_) {},
              onImportToWish: (_) {},
              objStoreService: objStoreService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_pick_types_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('主菜'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_roll_button')),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 2000));

      expect(
        find.byKey(const ValueKey('overcooked_gacha_draw_overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('overcooked_gacha_draw_card_name')),
        findsOneWidget,
      );
      expect(objStoreService.getCachedFileCallCount, greaterThan(0));
      expect(objStoreService.ensureCachedFileCallCount, 0);
    });

    testWidgets('抽卡流程结束后应揭晓随机菜品并进入列表', (tester) async {
      final now = DateTime(2026, 1, 2, 10);
      final typeTag = Tag(
        id: 1,
        name: '主菜',
        color: null,
        sortIndex: 0,
        createdAt: now,
        updatedAt: now,
      );
      tagService = _FakeTagService(db, tags: [typeTag]);
      repository = _FakeOvercookedRepository(
        db,
        recipes: [
          OvercookedRecipe.create(
            name: '红烧肉',
            coverImageKey: null,
            typeTagId: typeTag.id,
            ingredientTagIds: const [],
            sauceTagIds: const [],
            flavorTagIds: const [],
            intro: '',
            content: '',
            detailImageKeys: const [],
            now: now,
          ).copyWith(id: 100),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<OvercookedRepository>.value(value: repository),
          ],
          child: TestAppWrapper(
            child: OvercookedGachaTab(
              targetDate: DateTime(2026, 1, 2),
              onTargetDateChanged: (_) {},
              onImportToWish: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_pick_types_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('主菜'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_roll_button')),
      );
      await tester.pump(const Duration(milliseconds: 1600));

      expect(
        find.byKey(const ValueKey('overcooked_gacha_draw_overlay')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('overcooked_gacha_draw_card')),
        findsOneWidget,
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(
        find.byKey(const ValueKey('overcooked_gacha_draw_overlay')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('overcooked_gacha_picked_card-100')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('应按约3秒每张的节奏抽卡并逐张加入列表', (tester) async {
      final now = DateTime(2026, 1, 2, 10);
      final typeTag = Tag(
        id: 1,
        name: '主菜',
        color: null,
        sortIndex: 0,
        createdAt: now,
        updatedAt: now,
      );
      tagService = _FakeTagService(db, tags: [typeTag]);
      repository = _FakeOvercookedRepository(
        db,
        recipes: [
          OvercookedRecipe.create(
            name: '红烧肉',
            coverImageKey: null,
            typeTagId: typeTag.id,
            ingredientTagIds: const [],
            sauceTagIds: const [],
            flavorTagIds: const [],
            intro: '',
            content: '',
            detailImageKeys: const [],
            now: now,
          ).copyWith(id: 100),
          OvercookedRecipe.create(
            name: '青椒土豆丝',
            coverImageKey: null,
            typeTagId: typeTag.id,
            ingredientTagIds: const [],
            sauceTagIds: const [],
            flavorTagIds: const [],
            intro: '',
            content: '',
            detailImageKeys: const [],
            now: now,
          ).copyWith(id: 101),
        ],
        recipeStats: const {
          100: (cookCount: 8, avgRating: 5.0, ratingCount: 6),
          101: (cookCount: 3, avgRating: 1.0, ratingCount: 2),
        },
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<OvercookedRepository>.value(value: repository),
          ],
          child: TestAppWrapper(
            child: OvercookedGachaTab(
              targetDate: DateTime(2026, 1, 2),
              onTargetDateChanged: (_) {},
              onImportToWish: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_pick_types_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('主菜'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('overcooked_gacha_count_add-1')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_roll_button')),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.byKey(const ValueKey('overcooked_gacha_draw_overlay')),
        findsOneWidget,
      );
      expect(find.text('已加入列表 0/2'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 3200));
      expect(find.text('已加入列表 1/2'), findsOneWidget);
      final firstPickedCount =
          find.byKey(const ValueKey('overcooked_gacha_picked_card-100')).evaluate().length +
          find.byKey(const ValueKey('overcooked_gacha_picked_card-101')).evaluate().length;
      expect(firstPickedCount, 1);

      await tester.pump(const Duration(milliseconds: 3200));
      expect(
        find.byKey(const ValueKey('overcooked_gacha_draw_overlay')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('overcooked_gacha_picked_card-100')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('overcooked_gacha_picked_card-101')),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('无菜品的风格标签不可选择', (tester) async {
      final now = DateTime(2026, 1, 2, 10);
      final mainTag = Tag(
        id: 1,
        name: '主菜',
        color: null,
        sortIndex: 0,
        createdAt: now,
        updatedAt: now,
      );
      final dessertTag = Tag(
        id: 2,
        name: '甜品',
        color: null,
        sortIndex: 1,
        createdAt: now,
        updatedAt: now,
      );
      tagService = _FakeTagService(db, tags: [mainTag, dessertTag]);
      repository = _FakeOvercookedRepository(
        db,
        recipes: [
          OvercookedRecipe.create(
            name: '红烧肉',
            coverImageKey: null,
            typeTagId: mainTag.id,
            ingredientTagIds: const [],
            sauceTagIds: const [],
            flavorTagIds: const [],
            intro: '',
            content: '',
            detailImageKeys: const [],
            now: now,
          ).copyWith(id: 101),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<OvercookedRepository>.value(value: repository),
          ],
          child: TestAppWrapper(
            child: OvercookedGachaTab(
              targetDate: DateTime(2026, 1, 2),
              onTargetDateChanged: (_) {},
              onImportToWish: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_pick_types_button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('甜品'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(find.text('未选择'), findsOneWidget);
      final rollButton = tester.widget<CupertinoButton>(
        find.byKey(const ValueKey('overcooked_gacha_roll_button')),
      );
      expect(rollButton.onPressed, isNull);

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_pick_types_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('主菜'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      final rollButtonAfterPick = tester.widget<CupertinoButton>(
        find.byKey(const ValueKey('overcooked_gacha_roll_button')),
      );
      expect(rollButtonAfterPick.onPressed, isNotNull);
    });

    testWidgets('refreshToken 变化后应刷新风格可选状态', (tester) async {
      final now = DateTime(2026, 1, 2, 10);
      final typeTag = Tag(
        id: 1,
        name: '主菜',
        color: null,
        sortIndex: 0,
        createdAt: now,
        updatedAt: now,
      );
      final recipes = <OvercookedRecipe>[];
      tagService = _FakeTagService(db, tags: [typeTag]);
      repository = _FakeOvercookedRepository(db, recipes: recipes);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<OvercookedRepository>.value(value: repository),
          ],
          child: TestAppWrapper(
            child: OvercookedGachaTab(
              targetDate: DateTime(2026, 1, 2),
              onTargetDateChanged: (_) {},
              onImportToWish: (_) {},
              refreshToken: 0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_pick_types_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('主菜'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      final rollButtonBefore = tester.widget<CupertinoButton>(
        find.byKey(const ValueKey('overcooked_gacha_roll_button')),
      );
      expect(rollButtonBefore.onPressed, isNull);

      recipes.add(
        OvercookedRecipe.create(
          name: '红烧肉',
          coverImageKey: null,
          typeTagId: typeTag.id,
          ingredientTagIds: const [],
          sauceTagIds: const [],
          flavorTagIds: const [],
          intro: '',
          content: '',
          detailImageKeys: const [],
          now: now,
        ).copyWith(id: 200),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<OvercookedRepository>.value(value: repository),
          ],
          child: TestAppWrapper(
            child: OvercookedGachaTab(
              targetDate: DateTime(2026, 1, 2),
              onTargetDateChanged: (_) {},
              onImportToWish: (_) {},
              refreshToken: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_pick_types_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('主菜'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      final rollButtonAfter = tester.widget<CupertinoButton>(
        find.byKey(const ValueKey('overcooked_gacha_roll_button')),
      );
      expect(rollButtonAfter.onPressed, isNotNull);
    });

    testWidgets('份数达到风格菜品上限后提示且不再增加', (tester) async {
      final now = DateTime(2026, 1, 2, 10);
      final typeTag = Tag(
        id: 1,
        name: '主菜',
        color: null,
        sortIndex: 0,
        createdAt: now,
        updatedAt: now,
      );
      tagService = _FakeTagService(db, tags: [typeTag]);
      repository = _FakeOvercookedRepository(
        db,
        recipes: [
          OvercookedRecipe.create(
            name: '红烧肉',
            coverImageKey: null,
            typeTagId: typeTag.id,
            ingredientTagIds: const [],
            sauceTagIds: const [],
            flavorTagIds: const [],
            intro: '',
            content: '',
            detailImageKeys: const [],
            now: now,
          ).copyWith(id: 100),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<OvercookedRepository>.value(value: repository),
          ],
          child: TestAppWrapper(
            child: OvercookedGachaTab(
              targetDate: DateTime(2026, 1, 2),
              onTargetDateChanged: (_) {},
              onImportToWish: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_pick_types_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('主菜'));
      await tester.tap(find.text('完成'));
      await tester.pumpAndSettle();

      expect(find.text('共 1 道'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_count_add-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text('当前风格“主菜”只有 1 道可抽菜品，不能再加啦。'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();

      expect(find.text('共 1 道'), findsOneWidget);
    });
  });
}
