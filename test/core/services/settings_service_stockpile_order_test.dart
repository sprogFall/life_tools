import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_helper.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('SettingsService - 囤货助手排序', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      ToolRegistry.instance.registerAll();
    });

    tearDown(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('tool_order');
      await DatabaseHelper.instance.close();
    });

    test('旧的 tool_order 只有工作记录/标签管理时，init 会把囤货助手插入到两者之间', () async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('tool_order');

      final initial = ['work_log', 'tag_manager'];
      for (var i = 0; i < initial.length; i++) {
        await db.insert('tool_order', {'tool_id': initial[i], 'sort_index': i});
      }

      final service = SettingsService();
      await service.init();

      expect(
        service.toolOrder,
        ['work_log', 'stockpile_assistant', 'tag_manager'],
      );
    });
  });
}

