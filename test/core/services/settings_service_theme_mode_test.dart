import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('SettingsService 主题模式', () {
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

    test('默认应使用浅色模式', () async {
      final service = SettingsService(databaseProvider: () async => db);
      await service.init();

      expect(service.themeMode, ThemeMode.light);
      expect(service.isDarkModeEnabled, isFalse);
    });

    test('开启暗黑模式后重新初始化应保留配置', () async {
      final service = SettingsService(databaseProvider: () async => db);
      await service.init();
      await service.setDarkModeEnabled(true);

      final reloaded = SettingsService(databaseProvider: () async => db);
      await reloaded.init();

      expect(reloaded.themeMode, ThemeMode.dark);
      expect(reloaded.isDarkModeEnabled, isTrue);
    });

    test('开启跟随系统模式后重新初始化应保留配置', () async {
      final service = SettingsService(databaseProvider: () async => db);
      await service.init();
      await service.setThemeMode(ThemeMode.system);

      final reloaded = SettingsService(databaseProvider: () async => db);
      await reloaded.init();

      expect(reloaded.themeMode, ThemeMode.system);
      expect(reloaded.isDarkModeEnabled, isFalse);
    });
  });
}
