import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/sync/interfaces/tool_sync_provider.dart';
import 'package:life_tools/core/sync/models/sync_config.dart';
import 'package:life_tools/core/sync/services/backup_restore_service.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeToolSyncProvider implements ToolSyncProvider {
  @override
  final String toolId;

  final Map<String, dynamic> exportPayload;
  Map<String, dynamic>? lastImported;

  _FakeToolSyncProvider({
    required this.toolId,
    required this.exportPayload,
  });

  @override
  Future<Map<String, dynamic>> exportData() async => exportPayload;

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    lastImported = data;
  }
}

void main() {
  group('BackupRestoreService', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('exportAsJson 应包含同步配置与工具数据', () async {
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

      final tool = _FakeToolSyncProvider(
        toolId: 'work_log',
        exportPayload: const {'version': 1, 'data': {'tasks': []}},
      );

      final service = BackupRestoreService(
        syncConfigService: syncConfigService,
        toolProviders: [tool],
      );

      final jsonText = await service.exportAsJson();
      final map = jsonDecode(jsonText) as Map<String, dynamic>;

      expect(map['version'], isA<int>());
      expect(map['sync_config'], isA<Map>());
      expect(map['tools'], isA<Map>());
      expect((map['tools'] as Map).containsKey('work_log'), isTrue);
    });

    test('restoreFromJson 应调用配置保存与工具导入', () async {
      final syncConfigService = SyncConfigService();
      await syncConfigService.init();

      final tool = _FakeToolSyncProvider(
        toolId: 'work_log',
        exportPayload: const {'version': 1, 'data': {'tasks': []}},
      );

      final service = BackupRestoreService(
        syncConfigService: syncConfigService,
        toolProviders: [tool],
      );

      final payload = {
        'version': 1,
        'exported_at': DateTime(2026, 1, 1).millisecondsSinceEpoch,
        'sync_config': const SyncConfig(
          userId: 'u2',
          networkType: SyncNetworkType.privateWifi,
          serverUrl: 'sync.example.com',
          serverPort: 443,
          customHeaders: {},
          allowedWifiNames: ['MyWifi'],
        ).toMap(),
        'tools': {
          'work_log': {'version': 1, 'data': {'tasks': []}},
        },
      };

      await service.restoreFromJson(jsonEncode(payload));

      expect(syncConfigService.config, isNotNull);
      expect(syncConfigService.config!.userId, 'u2');
      expect(tool.lastImported, isNotNull);
      expect(tool.lastImported!['version'], 1);
    });
  });
}

