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
  final void Function(Map<String, dynamic> data)? onImport;
  Map<String, dynamic>? lastImported;

  _FakeToolSyncProvider({
    required this.toolId,
    required this.exportPayload,
    this.onImport,
  });

  @override
  Future<Map<String, dynamic>> exportData() async => exportPayload;

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    lastImported = data;
    onImport?.call(data);
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

    test('restoreFromJson 应优先导入 tag_manager，避免其它工具的标签关联丢失', () async {
      final aiConfigService = AiConfigService();
      await aiConfigService.init();

      final syncConfigService = SyncConfigService();
      await syncConfigService.init();

      final settingsService = SettingsService();
      await settingsService.init();

      var tagsImported = false;
      final tagProvider = _FakeToolSyncProvider(
        toolId: 'tag_manager',
        exportPayload: const {
          'version': 1,
          'data': {'tags': [], 'tool_tags': []},
        },
        onImport: (_) => tagsImported = true,
      );

      final dependentProvider = _FakeToolSyncProvider(
        toolId: 'work_log',
        exportPayload: const {'version': 1, 'data': {}},
        onImport: (_) {
          if (!tagsImported) {
            throw Exception('tags 未先导入');
          }
        },
      );

      final service = BackupRestoreService(
        aiConfigService: aiConfigService,
        syncConfigService: syncConfigService,
        settingsService: settingsService,
        toolProviders: [tagProvider, dependentProvider],
      );

      // tools 节点的插入顺序是 work_log -> tag_manager（模拟历史导出顺序）
      final payload = {
        'version': 1,
        'exported_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'ai_config': null,
        'sync_config': null,
        'settings': {
          'default_tool_id': null,
          'tool_order': ['work_log', 'tag_manager'],
        },
        'tools': {
          'work_log': {'version': 1, 'data': {}},
          'tag_manager': {
            'version': 1,
            'data': {'tags': [], 'tool_tags': []},
          },
        },
      };

      await service.restoreFromJson(jsonEncode(payload));

      expect(tagsImported, isTrue);
      expect(tagProvider.lastImported, isNotNull);
      expect(dependentProvider.lastImported, isNotNull);
    });

    test('restoreFromJson 应支持 ai_config/sync_config 为 JSON 字符串（避免偶现跳过导入）', () async {
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

      final aiConfigJson = jsonEncode(
        const AiConfig(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'k_json_string',
          model: 'm_json_string',
          temperature: 0.7,
          maxOutputTokens: 256,
        ).toMap(),
      );

      final syncConfigJson = jsonEncode(
        const SyncConfig(
          userId: 'u_json_string',
          networkType: SyncNetworkType.privateWifi,
          serverUrl: 'sync.example.com',
          serverPort: 443,
          customHeaders: {'X-Test': '1'},
          allowedWifiNames: ['MyWifi'],
          autoSyncOnStartup: true,
        ).toMap(),
      );

      final payload = {
        'version': 1,
        'exported_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'ai_config': aiConfigJson,
        'sync_config': syncConfigJson,
        'settings': {'default_tool_id': null, 'tool_order': const <String>[]},
        'tools': const <String, dynamic>{},
      };

      await service.restoreFromJson(jsonEncode(payload));

      expect(aiConfigService.config, isNotNull);
      expect(aiConfigService.config!.apiKey, 'k_json_string');
      expect(syncConfigService.config, isNotNull);
      expect(syncConfigService.config!.userId, 'u_json_string');
      expect(syncConfigService.config!.networkType, SyncNetworkType.privateWifi);
    });

    test('restoreFromJson 应容错 sync_config 数字字段为小数/字符串', () async {
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

      final jsonText = jsonEncode({
        'version': 1,
        'exported_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'ai_config': null,
        'sync_config': {
          'userId': 'u_num_loose',
          'networkType': 1.0,
          'serverUrl': 'sync.example.com',
          'serverPort': '443',
          'customHeaders': {'X-Test': '1'},
          'allowedWifiNames': ['MyWifi'],
          'autoSyncOnStartup': true,
          'lastSyncTime': 1700000000000.0,
        },
        'settings': {'default_tool_id': null, 'tool_order': const <String>[]},
        'tools': const <String, dynamic>{},
      });

      await service.restoreFromJson(jsonText);

      expect(syncConfigService.config, isNotNull);
      expect(syncConfigService.config!.userId, 'u_num_loose');
      expect(syncConfigService.config!.networkType, SyncNetworkType.privateWifi);
      expect(syncConfigService.config!.serverPort, 443);
      expect(
        syncConfigService.config!.lastSyncTime,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });
  });
}
