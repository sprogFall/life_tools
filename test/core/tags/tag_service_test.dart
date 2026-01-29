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
    test('空 toolId 返回空列表', () {
      final service = TagService(repository: tagRepository);
      final categories = service.categoriesForTool('');
      expect(categories, isEmpty);
    });

    test('未注册工具分类时返回空列表', () {
      final service = TagService(repository: tagRepository);
      final categories = service.categoriesForTool('some_tool');
      expect(categories, isEmpty);
    });

    test('注册分类会去重/trim，并忽略空值', () {
      final service = TagService(repository: tagRepository);
      service.registerToolTagCategories('tool', const [
        TagCategory(id: ' a ', name: ' A ', createHint: ' 例子 '),
        TagCategory(id: 'a', name: '重复', createHint: '应忽略'),
        TagCategory(id: '', name: '忽略'),
        TagCategory(id: 'b', name: ''),
      ]);

      final categories = service.categoriesForTool('tool');
      expect(categories.map((e) => e.id), ['a']);
      expect(categories.single.name, 'A');
      expect(categories.single.createHint, '例子');
    });
  });

  group('BuiltInTagCategories.registerAll', () {
    test('启动时可一次性注册胡闹厨房分类', () {
      final service = TagService(repository: tagRepository);
      BuiltInTagCategories.registerAll(service);

      final categories = service.categoriesForTool(OvercookedConstants.toolId);
      expect(
        categories.map((e) => e.id).toSet(),
        containsAll(<String>{
          OvercookedTagCategories.dishType,
          OvercookedTagCategories.ingredient,
          OvercookedTagCategories.sauce,
          OvercookedTagCategories.flavor,
          OvercookedTagCategories.mealSlot,
        }),
      );
    });
  });

  group('TagService.createTagForToolCategory', () {
    test('categoryId 为空时抛出异常', () async {
      final service = TagService(repository: tagRepository);

      await expectLater(
        () => service.createTagForToolCategory(
          toolId: 'work_log',
          categoryId: '',
          name: '紧急',
        ),
        throwsArgumentError,
      );
    });

    test('categoryId 指定时写入对应分类', () async {
      final service = TagService(repository: tagRepository);

      final id = await service.createTagForToolCategory(
        toolId: 'work_log',
        categoryId: 'priority',
        name: '重要',
      );
      expect(id, greaterThan(0));

      final tags = await service.listTagsForToolCategory(
        toolId: 'work_log',
        categoryId: 'priority',
      );
      expect(tags.map((e) => e.id), contains(id));
    });
  });
}
