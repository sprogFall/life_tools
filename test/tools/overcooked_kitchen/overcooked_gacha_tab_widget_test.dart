import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/tags/models/tag.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/pages/tabs/overcooked_gacha_tab.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
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
  final List<({DateTime date, int recipeId})> addedWishes = [];

  // ignore: use_super_parameters
  _FakeOvercookedRepository(Database db, {required this.recipes})
    : super.withDatabase(db);

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

      expect(find.byKey(const ValueKey('overcooked_gacha_import_button')), findsOneWidget);
      expect(find.text('就你了'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('overcooked_gacha_import_button')),
      );
      await tester.pumpAndSettle();

      expect(importedDate, DateTime(2026, 1, 2));
      expect(
        (repository as _FakeOvercookedRepository).addedWishes,
        [(date: DateTime(2026, 1, 2), recipeId: 100)],
      );
    });
  });
}
