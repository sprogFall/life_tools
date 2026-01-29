import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('SettingsService 工具管理', () {
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

    test('隐藏工具后 getHomeTools 应不包含该工具', () async {
      final service = SettingsService(databaseProvider: () async => db);
      await service.init();

      expect(service.getHomeTools().any((t) => t.id == 'work_log'), isTrue);

      await service.setToolHidden('work_log', true);
      expect(service.getHomeTools().any((t) => t.id == 'work_log'), isFalse);

      await service.setToolHidden('work_log', false);
      expect(service.getHomeTools().any((t) => t.id == 'work_log'), isTrue);
    });

    test('首页重排只作用于可见工具，应保持隐藏工具占位顺序', () async {
      final service = SettingsService(databaseProvider: () async => db);
      await service.init();

      await service.updateToolOrder([
        'work_log',
        'stockpile_assistant',
        'overcooked_kitchen',
        'tag_manager',
      ]);

      await service.setToolHidden('stockpile_assistant', true);
      expect(service.toolOrder, [
        'work_log',
        'stockpile_assistant',
        'overcooked_kitchen',
        'tag_manager',
      ]);

      // 可见工具：work_log / overcooked_kitchen / tag_manager
      // 把 overcooked_kitchen 拖到最前。
      await service.updateHomeToolOrder([
        'overcooked_kitchen',
        'work_log',
        'tag_manager',
      ]);

      // stockpile_assistant 仍占据中间位置（不可见但不应被挪走）
      expect(service.toolOrder, [
        'overcooked_kitchen',
        'stockpile_assistant',
        'work_log',
        'tag_manager',
      ]);
    });
  });
}
