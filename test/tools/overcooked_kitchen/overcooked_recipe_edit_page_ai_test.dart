import 'dart:io';

import 'package:flutter/cupertino.dart';
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
import 'package:life_tools/tools/overcooked_kitchen/ai/overcooked_recipe_ai_assistant.dart';
import 'package:life_tools/tools/overcooked_kitchen/models/overcooked_recipe.dart';
import 'package:life_tools/tools/overcooked_kitchen/overcooked_constants.dart';
import 'package:life_tools/tools/overcooked_kitchen/pages/recipe/overcooked_recipe_edit_page.dart';
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
    if (toolId != OvercookedConstants.toolId) {
      return const [];
    }
    final now = DateTime(2026, 2, 8, 12);
    switch (categoryId) {
      case OvercookedTagCategories.dishType:
        return [
          Tag(
            id: 1,
            name: '家常',
            color: null,
            sortIndex: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ];
      case OvercookedTagCategories.ingredient:
        return [
          Tag(
            id: 11,
            name: '鸡腿肉',
            color: null,
            sortIndex: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ];
      case OvercookedTagCategories.sauce:
        return [
          Tag(
            id: 21,
            name: '生抽',
            color: null,
            sortIndex: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ];
      case OvercookedTagCategories.flavor:
        return [
          Tag(
            id: 31,
            name: '鲜香',
            color: null,
            sortIndex: 0,
            createdAt: now,
            updatedAt: now,
          ),
        ];
      default:
        return const [];
    }
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
              p.join(Directory.systemTemp.path, 'obj_store_edit_test'),
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

class _FakeRecipeAiAssistant implements OvercookedRecipeAiAssistant {
  String? lastName;
  String? lastStyle;
  List<String>? lastIngredients;
  List<String>? lastSauces;
  List<String>? lastFlavors;
  String? lastIntro;

  @override
  Future<String> generateRecipeMarkdown({
    required String name,
    String? style,
    required List<String> ingredients,
    required List<String> sauces,
    required List<String> flavors,
    required String intro,
  }) async {
    lastName = name;
    lastStyle = style;
    lastIngredients = ingredients;
    lastSauces = sauces;
    lastFlavors = flavors;
    lastIntro = intro;

    await Future<void>.delayed(const Duration(milliseconds: 80));
    return '''
## 食材与用量
- 鸡腿肉 300g

## 制作步骤
1. 热锅下油。
''';
  }
}

Finder _findFieldByPlaceholder(String placeholder) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is CupertinoTextField && widget.placeholder == placeholder,
  );
}

Finder _findAiGenerateButton() {
  return find.byWidgetPredicate(
    (widget) => widget is Icon && widget.icon == CupertinoIcons.sparkles,
  );
}

void main() {
  group('OvercookedRecipeEditPage AI 生成', () {
    late Database db;
    late TagService tagService;
    late ObjStoreService objStoreService;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath);
      tagService = _FakeTagService(db);
      objStoreService = _FakeObjStoreService();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('点击 AI 生成会展示遮罩并回填 Markdown 内容', (tester) async {
      final assistant = _FakeRecipeAiAssistant();
      final recipe = OvercookedRecipe.create(
        name: '香煎鸡腿排',
        coverImageKey: null,
        typeTagId: 1,
        ingredientTagIds: const [11],
        sauceTagIds: const [21],
        flavorTagIds: const [31],
        intro: '20 分钟快手菜',
        content: '',
        detailImageKeys: const [],
        now: DateTime(2026, 2, 8, 10),
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<ObjStoreService>.value(value: objStoreService),
          ],
          child: TestAppWrapper(
            child: OvercookedRecipeEditPage(
              initial: recipe,
              aiAssistant: assistant,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listView = find.byType(ListView).first;
      await tester.drag(listView, const Offset(0, -600));
      await tester.pumpAndSettle();

      await tester.tap(_findAiGenerateButton());
      await tester.pump();

      expect(find.text('菜谱生成中…'), findsOneWidget);

      await tester.pumpAndSettle();

      expect(assistant.lastName, '香煎鸡腿排');
      expect(assistant.lastStyle, '家常');
      expect(assistant.lastIngredients, ['鸡腿肉']);
      expect(assistant.lastSauces, ['生抽']);
      expect(assistant.lastFlavors, ['鲜香']);
      expect(assistant.lastIntro, '20 分钟快手菜');
      expect(find.text('菜谱生成中…'), findsNothing);

      final contentField = tester.widget<CupertinoTextField>(
        _findFieldByPlaceholder('写下步骤、火候、注意事项…'),
      );
      expect(contentField.controller?.text, contains('## 制作步骤'));
      expect(contentField.controller?.text, contains('热锅下油'));
    });

    testWidgets('未填写菜名时点击 AI 生成会提示并阻断调用', (tester) async {
      final assistant = _FakeRecipeAiAssistant();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tagService),
            Provider<ObjStoreService>.value(value: objStoreService),
          ],
          child: TestAppWrapper(
            child: OvercookedRecipeEditPage(aiAssistant: assistant),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final listView = find.byType(ListView).first;
      await tester.drag(listView, const Offset(0, -600));
      await tester.pumpAndSettle();

      await tester.tap(_findAiGenerateButton());
      await tester.pumpAndSettle();

      expect(find.text('请先填写菜名，再使用 AI 生成。'), findsOneWidget);
      expect(assistant.lastName, isNull);
    });
  });
}
