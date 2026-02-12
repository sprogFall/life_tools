import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/secret_store/secret_store.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/core/sync/interfaces/tool_sync_provider.dart';
import 'package:life_tools/core/sync/models/sync_config.dart';
import 'package:life_tools/core/sync/models/sync_force_decision.dart';
import 'package:life_tools/core/sync/services/sync_api_client.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:life_tools/core/sync/services/sync_local_state_service.dart';
import 'package:life_tools/core/sync/services/sync_service.dart';
import 'package:life_tools/core/sync/services/wifi_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/recording_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService 用户不匹配保护', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('自动同步遇到用户不匹配应阻止且不发起网络请求', () async {
      final configService = SyncConfigService();
      await configService.init();
      await configService.save(
        const SyncConfig(
          userId: 'server_user',
          networkType: SyncNetworkType.public,
          serverUrl: 'example.com',
          serverPort: 443,
          customHeaders: {},
          allowedWifiNames: [],
          autoSyncOnStartup: true,
        ),
      );

      final localStateService = SyncLocalStateService();
      await localStateService.init();
      await localStateService.setLocalUserId('local_user');

      final httpClient = RecordingHttpClient((_) async {
        throw StateError('不应触发网络请求');
      });
      final apiClient = SyncApiClient(httpClient: httpClient);

      final syncService = SyncService(
        configService: configService,
        localStateService: localStateService,
        aiConfigService: AiConfigService(),
        settingsService: SettingsService(databaseProvider: () async => throw 0),
        objStoreConfigService: ObjStoreConfigService(
          secretStore: _FakeSecretStore(),
        ),
        wifiService: _FakeWifiService(NetworkStatus.wifi),
        apiClient: apiClient,
        toolProviders: const [],
      );

      final ok = await syncService.sync(trigger: SyncTrigger.auto);

      expect(ok, isFalse);
      expect(httpClient.lastRequest, isNull);
      expect(syncService.lastError, contains('无法自动同步'));
      expect(syncService.lastError, contains('用户不匹配'));
    });

    test('手动同步遇到用户不匹配应阻止且不发起网络请求', () async {
      final configService = SyncConfigService();
      await configService.init();
      await configService.save(
        const SyncConfig(
          userId: 'server_user',
          networkType: SyncNetworkType.public,
          serverUrl: 'example.com',
          serverPort: 443,
          customHeaders: {},
          allowedWifiNames: [],
          autoSyncOnStartup: true,
        ),
      );

      final localStateService = SyncLocalStateService();
      await localStateService.init();
      await localStateService.setLocalUserId('local_user');

      final httpClient = RecordingHttpClient((_) async {
        throw StateError('不应触发网络请求');
      });

      final syncService = SyncService(
        configService: configService,
        localStateService: localStateService,
        aiConfigService: AiConfigService(),
        settingsService: SettingsService(databaseProvider: () async => throw 0),
        objStoreConfigService: ObjStoreConfigService(
          secretStore: _FakeSecretStore(),
        ),
        wifiService: _FakeWifiService(NetworkStatus.wifi),
        apiClient: SyncApiClient(httpClient: httpClient),
        toolProviders: const [],
      );

      final ok = await syncService.sync(trigger: SyncTrigger.manual);

      expect(ok, isFalse);
      expect(httpClient.lastRequest, isNull);
      expect(syncService.lastError, contains('请选择'));
      expect(syncService.lastError, contains('覆盖'));
    });

    test('选择覆盖本地（use_server）应发送空 tools_data，并在服务端无快照时清空本地工具数据', () async {
      final configService = SyncConfigService();
      await configService.init();
      await configService.save(
        const SyncConfig(
          userId: 'server_user',
          networkType: SyncNetworkType.public,
          serverUrl: 'example.com',
          serverPort: 443,
          customHeaders: {},
          allowedWifiNames: [],
          autoSyncOnStartup: true,
        ),
      );

      final localStateService = SyncLocalStateService();
      await localStateService.init();
      await localStateService.setLocalUserId('local_user');

      final toolProvider = _RecordingToolProvider();

      final httpClient = RecordingHttpClient((request) async {
        final req = request as http.Request;
        final payload = jsonDecode(req.body) as Map<String, dynamic>;
        expect(payload['force_decision'], 'use_server');
        expect(payload['tools_data'], isEmpty);

        final body = jsonEncode({
          'success': true,
          'decision': 'noop',
          'message': 'no snapshot',
          'server_time': 1730000000000,
          'server_revision': 0,
        });
        return http.StreamedResponse(
          Stream.value(Uint8List.fromList(utf8.encode(body))),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final syncService = SyncService(
        configService: configService,
        localStateService: localStateService,
        aiConfigService: AiConfigService(),
        settingsService: SettingsService(databaseProvider: () async => throw 0),
        objStoreConfigService: ObjStoreConfigService(
          secretStore: _FakeSecretStore(),
        ),
        wifiService: _FakeWifiService(NetworkStatus.wifi),
        apiClient: SyncApiClient(httpClient: httpClient),
        toolProviders: [toolProvider],
      );

      final ok = await syncService.sync(
        trigger: SyncTrigger.manual,
        forceDecision: SyncForceDecision.useServer,
      );

      expect(ok, isTrue);
      expect(toolProvider.imported, isNotNull);
      expect((toolProvider.imported!['data'] as Map).isNotEmpty, isTrue);
      expect(localStateService.localUserId, 'server_user');
    });

    test('选择覆盖服务端（use_client）应携带 force_decision=use_client', () async {
      final configService = SyncConfigService();
      await configService.init();
      await configService.save(
        const SyncConfig(
          userId: 'server_user',
          networkType: SyncNetworkType.public,
          serverUrl: 'example.com',
          serverPort: 443,
          customHeaders: {},
          allowedWifiNames: [],
          autoSyncOnStartup: true,
        ),
      );

      final localStateService = SyncLocalStateService();
      await localStateService.init();
      await localStateService.setLocalUserId('local_user');

      final toolProvider = _RecordingToolProvider();

      final httpClient = RecordingHttpClient((request) async {
        final req = request as http.Request;
        final payload = jsonDecode(req.body) as Map<String, dynamic>;
        expect(payload['force_decision'], 'use_client');
        expect((payload['tools_data'] as Map).isNotEmpty, isTrue);

        final body = jsonEncode({
          'success': true,
          'decision': 'use_client',
          'message': 'forced',
          'server_time': 1730000000000,
          'server_revision': 2,
        });
        return http.StreamedResponse(
          Stream.value(Uint8List.fromList(utf8.encode(body))),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final syncService = SyncService(
        configService: configService,
        localStateService: localStateService,
        aiConfigService: AiConfigService(),
        settingsService: SettingsService(databaseProvider: () async => throw 0),
        objStoreConfigService: ObjStoreConfigService(
          secretStore: _FakeSecretStore(),
        ),
        wifiService: _FakeWifiService(NetworkStatus.wifi),
        apiClient: SyncApiClient(httpClient: httpClient),
        toolProviders: [toolProvider],
      );

      final ok = await syncService.sync(
        trigger: SyncTrigger.manual,
        forceDecision: SyncForceDecision.useClient,
      );

      expect(ok, isTrue);
      expect(toolProvider.imported, isNull);
      expect(localStateService.localUserId, 'server_user');
    });
  });
}

class _FakeSecretStore implements SecretStore {
  final _values = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    _values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return _values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }
}

class _FakeWifiService extends WifiService {
  final NetworkStatus _status;

  _FakeWifiService(this._status);

  @override
  Future<NetworkStatus> getNetworkStatus() async => _status;

  @override
  Future<String?> getCurrentWifiName() async => null;
}

class _RecordingToolProvider implements ToolSyncProvider {
  Map<String, dynamic>? imported;

  @override
  String get toolId => 'recording_tool';

  @override
  Future<Map<String, dynamic>> exportData() async {
    return const {
      'version': 1,
      'data': {
        'items': [
          {'id': 1, 'updated_at': 123},
        ],
      },
    };
  }

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    imported = Map<String, dynamic>.from(data);
  }
}
