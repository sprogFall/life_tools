import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/built_in_tag_categories.dart';
import 'package:life_tools/core/tags/models/tag_category.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/tools/overcooked_kitchen/overcooked_constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
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
    tagRepository = TagRepository.withDatabase(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('TagService.categoriesForTool', () {
    test('空 toolId 只返回默认分类', () {
      final service = TagService(repository: tagRepository);
      final categories = service.categoriesForTool('');
      expect(categories.length, 1);
      expect(categories.single.id, TagRepository.defaultCategoryId);
    });

    test('未注册工具分类时，返回默认分类', () {
      final service = TagService(repository: tagRepository);
      final categories = service.categoriesForTool('some_tool');
      expect(categories.length, 1);
      expect(categories.single.id, TagRepository.defaultCategoryId);
    });

    test('注册分类会去重/trim，并自动补默认分类', () {
      final service = TagService(repository: tagRepository);
      service.registerToolTagCategories('tool', const [
        TagCategory(id: ' a ', name: ' A ', createHint: ' 例子 '),
        TagCategory(id: 'a', name: '重复', createHint: '应忽略'),
        TagCategory(id: '', name: '忽略'),
        TagCategory(id: 'b', name: ''),
      ]);

      final categories = service.categoriesForTool('tool');
      expect(categories.first.id, TagRepository.defaultCategoryId);
      expect(categories.map((e) => e.id), [
        TagRepository.defaultCategoryId,
        'a',
      ]);
      expect(categories.last.name, 'A');
      expect(categories.last.createHint, '例子');
    });

    test('已包含默认分类时不重复插入', () {
      final service = TagService(repository: tagRepository);
      service.registerToolTagCategories('tool', const [
        TagCategory(id: TagRepository.defaultCategoryId, name: '默认'),
        TagCategory(id: 'x', name: 'X', createHint: '示例'),
      ]);

      final categories = service.categoriesForTool('tool');
      expect(categories.map((e) => e.id), [
        TagRepository.defaultCategoryId,
        'x',
      ]);
    });
  });

  group('BuiltInTagCategories.registerAll', () {
    test('启动时可一次性注册胡闹厨房分类', () {
      final service = TagService(repository: tagRepository);
      BuiltInTagCategories.registerAll(service);

      final categories = service.categoriesForTool(OvercookedConstants.toolId);
      expect(
        categories.any((e) => e.id == TagRepository.defaultCategoryId),
        isTrue,
      );
      expect(
        categories.map((e) => e.id).toSet(),
        containsAll(<String>{
          OvercookedTagCategories.dishType,
          OvercookedTagCategories.ingredient,
          OvercookedTagCategories.sauce,
          OvercookedTagCategories.flavor,
        }),
      );
    });
  });
}
