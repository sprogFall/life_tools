import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/core/sync/interfaces/tool_sync_provider.dart';
import 'package:life_tools/core/sync/models/sync_config.dart';
import 'package:life_tools/core/sync/services/backup_restore_service.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeToolSyncProvider implements ToolSyncProvider {
  @override
  final String toolId;

  final Map<String, dynamic> exportPayload;
  Map<String, dynamic>? lastImported;

  _FakeToolSyncProvider({required this.toolId, required this.exportPayload});

  @override
  Future<Map<String, dynamic>> exportData() async => exportPayload;

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    lastImported = data;
  }
}

void main() {
  group('BackupRestoreService', () {
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      ToolRegistry.instance.registerAll();
    });

    test('exportAsJson 应包含 AI 配置/同步配置/默认工具配置/工具数据', () async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();
      await aiConfigService.save(
        const AiConfig(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'k1',
          model: 'm1',
          temperature: 0.7,
          maxOutputTokens: 256,
        ),
      );

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();
      await syncConfigService.save(
        const SyncConfig(
          userId: 'u1',
          networkType: SyncNetworkType.public,
          serverUrl: 'sync.example.com',
          serverPort: 443,
          customHeaders: {'X-Test': '1'},
          allowedWifiNames: [],
          autoSyncOnStartup: false,
        ),
      );

      final settingsService = SettingsService();
      await settingsService.init();
      await settingsService.setDefaultTool('work_log');

      final tool = _FakeToolSyncProvider(
        toolId: 'work_log',
        exportPayload: const {
          'version': 1,
          'data': {'tasks': []},
        },
      );

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        toolProviders: [tool],
      );

      final jsonText = await service.exportAsJson();
      final map = jsonDecode(jsonText) as Map<String, dynamic>;

      expect(map['version'], isA<int>());
      expect(map['ai_config'], isA<Map>());
      expect(map['sync_config'], isA<Map>());
      expect(map['settings'], isA<Map>());
      expect(map['tools'], isA<Map>());
      expect((map['tools'] as Map).containsKey('work_log'), isTrue);
    });

    test('导出为 TXT 文件时应使用紧凑 JSON（不换行）', () async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();

      final settingsService = SettingsService();
      await settingsService.init();

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        toolProviders: const [],
      );

      final compact = await service.exportAsJson(pretty: false);
      expect(compact, isNot(contains('\n')));
      expect(compact, isNot(contains('\r')));

      final pretty = await service.exportAsJson(pretty: true);
      expect(pretty, contains('\n'));
    });

    test('restoreFromJson 应还原 AI 配置/同步配置/默认工具配置，并调用工具导入', () async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();

      final settingsService = SettingsService();
      await settingsService.init();

      final tool = _FakeToolSyncProvider(
        toolId: 'work_log',
        exportPayload: const {
          'version': 1,
          'data': {'tasks': []},
        },
      );

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        toolProviders: [tool],
      );

      final payload = {
        'version': 1,
        'exported_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'ai_config': const AiConfig(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'k2',
          model: 'm2',
          temperature: 0.2,
          maxOutputTokens: 512,
        ).toMap(),
        'sync_config': const SyncConfig(
          userId: 'u2',
          networkType: SyncNetworkType.privateWifi,
          serverUrl: 'sync.example.com',
          serverPort: 443,
          customHeaders: {},
          allowedWifiNames: ['MyWifi'],
        ).toMap(),
        'settings': {
          'default_tool_id': 'work_log',
          'tool_order': ['work_log', 'review', 'expense', 'income'],
        },
        'tools': {
          'work_log': {
            'version': 1,
            'data': {'tasks': []},
          },
        },
      };

      await service.restoreFromJson(jsonEncode(payload));

      expect(aiConfigService.config, isNotNull);
      expect(aiConfigService.config!.model, 'm2');
      expect(syncConfigService.config, isNotNull);
      expect(syncConfigService.config!.userId, 'u2');
      expect(settingsService.defaultToolId, 'work_log');
      expect(tool.lastImported, isNotNull);
      expect(tool.lastImported!['version'], 1);
    });
  });
}
