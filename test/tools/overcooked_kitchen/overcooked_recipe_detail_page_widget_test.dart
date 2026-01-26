import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/obj_store_errors.dart';
import 'package:life_tools/core/obj_store/obj_store_service.dart';
import 'package:life_tools/core/obj_store/qiniu/qiniu_client.dart';
import 'package:life_tools/core/obj_store/secret_store/in_memory_secret_store.dart';
import 'package:life_tools/core/obj_store/storage/local_obj_store.dart';
import 'package:life_tools/core/tags/models/tag.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/pages/recipe/overcooked_recipe_detail_page.dart';
import 'package:life_tools/tools/overcooked_kitchen/repository/overcooked_repository.dart';
import 'package:path/path.dart' as p;
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
    return const [];
  }
}

class _FakeOvercookedRepository extends OvercookedRepository {
  final OvercookedRecipe recipe;

  // ignore: use_super_parameters
  _FakeOvercookedRepository(Database db, {required this.recipe})
    : super.withDatabase(db);

  @override
  Future<OvercookedRecipe?> getRecipe(int id) async {
    return recipe.copyWith(id: id);
  }
}

class _FakeObjStoreService extends ObjStoreService {
  _FakeObjStoreService()
    : super(
        configService: ObjStoreConfigService(
          secretStore: InMemorySecretStore(),
        ),
        localStore: LocalObjStore(
          baseDirProvider: () async {
            final dir = Directory(
              p.join(Directory.systemTemp.path, 'obj_store'),
            );
            if (!dir.existsSync()) dir.createSync(recursive: true);
            return dir;
          },
        ),
        qiniuClient: QiniuClient(),
      );

  @override
  Future<String> resolveUri({required String key}) async {
    throw const ObjStoreNotConfiguredException();
  }
}

void main() {
  group('OvercookedRecipeDetailPage（Widget）', () {
    late Database db;
    late OvercookedRepository repository;
    late TagService tagService;

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

    testWidgets('图片未配置时仍可正常展示详情文本', (tester) async {
      final now = DateTime(2026, 1, 2, 10);
      final recipe = OvercookedRecipe.create(
        name: '测试菜谱',
        coverImageKey: 'any.png',
        typeTagId: null,
        ingredientTagIds: const [],
        sauceTagIds: const [],
        flavorTagIds: const [],
        intro: '简介文本',
        content: '正文内容',
        detailImageKeys: const [],
        now: now,
      );
      repository = _FakeOvercookedRepository(db, recipe: recipe);
      tagService = _FakeTagService(db);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<ObjStoreService>.value(value: _FakeObjStoreService()),
          ],
          child: TestAppWrapper(
            child: OvercookedRecipeDetailPage(
              recipeId: 1,
              repository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('测试菜谱'), findsOneWidget);
      expect(find.text('详细内容'), findsOneWidget);
      expect(find.text('正文内容'), findsOneWidget);
    });
  });
}
