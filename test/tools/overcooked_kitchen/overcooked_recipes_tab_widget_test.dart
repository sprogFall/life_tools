import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';
import 'package:life_tools/core/tags/models/tag.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/pages/tabs/overcooked_recipes_tab.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../test_helpers/test_app_wrapper.dart';

class _FakeTagService extends TagService {
  _FakeTagService(Database db)
    : super(repository: TagRepository.withDatabase(db));

  @override
  Future<List<Tag>> listTagsForToolCategory({
    required String toolId,
    required String categoryId,
    bool refresh = true,
  }) async {
    return const <Tag>[];
  }
}

class _FakeOvercookedRepository extends OvercookedRepository {
  // ignore: use_super_parameters
  _FakeOvercookedRepository(Database db) : super.withDatabase(db);

  @override
  Future<List<OvercookedRecipe>> listRecipes({int? typeTagId}) async {
    return const <OvercookedRecipe>[];
  }

  @override
  Future<Map<int, ({int cookCount, double avgRating, int ratingCount})>>
  getRecipeStats() async => const {};
}

void main() {
  group('OvercookedRecipesTab（Widget）', () {
    late Database db;
    late TagService tagService;
    late OvercookedRepository repository;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath);
      tagService = _FakeTagService(db);
      repository = _FakeOvercookedRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('页面文案应正常显示中文（避免出现 ??）', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<OvercookedRepository>.value(value: repository),
          ],
          child: TestAppWrapper(
            child: OvercookedRecipesTab(onJumpToGacha: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('菜谱'), findsOneWidget);
      expect(find.text('+ 新建'), findsOneWidget);
      expect(find.text('不知道吃什么？去扭蛋机抽一个'), findsOneWidget);
      expect(find.text('去扭蛋'), findsOneWidget);
      expect(find.text('搜索菜谱'), findsOneWidget);
    });

    testWidgets('扭蛋入口卡片在路由过渡时不应关闭毛玻璃', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<OvercookedRepository>.value(value: repository),
          ],
          child: TestAppWrapper(
            child: OvercookedRecipesTab(onJumpToGacha: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gachaCard = tester.widget<GlassContainer>(
        find.byKey(const ValueKey('overcooked_recipes_gacha_entry_card')),
      );
      expect(gachaCard.disableBlurDuringRouteTransition, isFalse);
    });
  });
}
