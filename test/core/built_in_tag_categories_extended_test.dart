import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/tags/built_in_tag_categories.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/core/tags/tag_service.dart';
import 'package:life_tools/tools/stockpile_assistant/stockpile_constants.dart';
import 'package:life_tools/tools/work_log/work_log_constants.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('BuiltInTagCategories', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    test('应为工作记录/囤货助手注册更明确的标签分类', () async {
      late Database db;
      late TagService service;
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      addTearDown(() async => db.close());

      service = TagService(repository: TagRepository.withDatabase(db));
      BuiltInTagCategories.registerAll(service);

      final workLogCategories = service.categoriesForTool('work_log');
      expect(
        workLogCategories.any(
          (c) => c.id == WorkLogTagCategories.affiliation && c.name == '归属',
        ),
        isTrue,
      );

      final stockpileCategories = service.categoriesForTool(
        'stockpile_assistant',
      );
      expect(
        stockpileCategories.any(
          (c) => c.id == StockpileTagCategories.itemType && c.name == '物品类型',
        ),
        isTrue,
      );
      expect(
        stockpileCategories.any(
          (c) => c.id == StockpileTagCategories.location && c.name == '位置',
        ),
        isTrue,
      );
    });
  });
}
