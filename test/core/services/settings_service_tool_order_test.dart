import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('SettingsService 工具排序', () {
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      ToolRegistry.instance.registerAll();

      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('init 时应确保标签管理在最后', () async {
      await db.delete('tool_order');

      // 模拟旧版本的持久化顺序：tag_manager 在第一位
      final initial = [
        'tag_manager',
        'work_log',
        'review',
        'expense',
        'income',
      ];
      for (var i = 0; i < initial.length; i++) {
        await db.insert('tool_order', {'tool_id': initial[i], 'sort_index': i});
      }

      final service = SettingsService(databaseProvider: () async => db);
      await service.init();

      expect(service.toolOrder.isNotEmpty, isTrue);
      expect(service.toolOrder.last, 'tag_manager');
      expect(service.toolOrder.where((e) => e == 'tag_manager').length, 1);
    });
  });
}
