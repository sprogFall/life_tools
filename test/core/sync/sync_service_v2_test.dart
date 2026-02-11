import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_call_history_service.dart';
import 'package:life_tools/core/ai/ai_call_source.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/secret_store/in_memory_secret_store.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/core/sync/interfaces/tool_sync_provider.dart';
import 'package:life_tools/core/sync/models/sync_config.dart';
import 'package:life_tools/core/sync/models/sync_request.dart';
import 'package:life_tools/core/sync/models/sync_request_v2.dart';
import 'package:life_tools/core/sync/models/sync_response.dart';
import 'package:life_tools/core/sync/models/sync_response_v2.dart';
import 'package:life_tools/core/sync/services/sync_api_client.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:life_tools/core/sync/services/sync_local_state_service.dart';
import 'package:life_tools/core/sync/services/sync_service.dart';
import 'package:life_tools/core/sync/services/app_config_updated_at.dart';
import 'package:life_tools/core/sync/services/wifi_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWifiService extends WifiService {
  final NetworkStatus status;

  _FakeWifiService(this.status);

  @override
  Future<NetworkStatus> getNetworkStatus() async => status;
}

class _FakeToolSyncProvider implements ToolSyncProvider {
  @override
  final String toolId;
  final Map<String, dynamic> exported;

  int importCalls = 0;
  Map<String, dynamic>? lastImported;

  _FakeToolSyncProvider({required this.toolId, required this.exported});

  @override
  Future<Map<String, dynamic>> exportData() async => exported;

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    importCalls++;
    lastImported = data;
  }
}

class _ThrowingToolSyncProvider implements ToolSyncProvider {
  @override
  final String toolId;

  _ThrowingToolSyncProvider({required this.toolId});

  @override
  Future<Map<String, dynamic>> exportData() async {
    throw StateError('export failed');
  }

  @override
  Future<void> importData(Map<String, dynamic> data) async {}
}

class _FakeSyncApiClient extends SyncApiClient {
  SyncRequestV2? lastRequestV2;
  SyncRequest? lastRequestV1;

  SyncResponseV2? v2Response;
  SyncResponse? v1Response;
  SyncApiException? v2Exception;

  _FakeSyncApiClient();

  @override
  Future<SyncResponseV2> syncV2({
    required SyncConfig config,
    required SyncRequestV2 request,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    lastRequestV2 = request;
    if (v2Exception != null) throw v2Exception!;
    return v2Response!;
  }

  @override
  Future<SyncResponse> sync({
    required SyncConfig config,
    required SyncRequest request,
    Duration timeout = const Duration(seconds: 120),
  }) async {
    lastRequestV1 = request;
    return v1Response!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncService v2', () {
    late SyncConfigService configService;
    late SyncLocalStateService localStateService;
    late AiConfigService aiConfigService;
    late AiCallHistoryService aiCallHistoryService;
    late SettingsService settingsService;
    late ObjStoreConfigService objStoreConfigService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      configService = SyncConfigService();
      await configService.init();
      localStateService = SyncLocalStateService();
      await localStateService.init();
      aiConfigService = AiConfigService();
      await aiConfigService.init();
      aiCallHistoryService = AiCallHistoryService();
      await aiCallHistoryService.init();
      settingsService = SettingsService();
      objStoreConfigService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService.init();
      await configService.save(
        const SyncConfig(
          userId: 'u1',
          networkType: SyncNetworkType.public,
          serverUrl: 'https://example.com',
          serverPort: 443,
          customHeaders: {},
          allowedWifiNames: [],
          autoSyncOnStartup: false,
          lastSyncTime: null,
          lastServerRevision: 7,
        ),
      );
    });

    test('服务端返回 use_server 时，导入服务端数据并更新游标', () async {
      final provider = _FakeToolSyncProvider(
        toolId: 'work_log',
        exported: const {
          'version': 1,
          'data': {'tasks': []},
        },
      );

      final api = _FakeSyncApiClient()
        ..v2Response = SyncResponseV2(
          success: true,
          decision: SyncDecision.useServer,
          serverTime: DateTime.fromMillisecondsSinceEpoch(1000),
          serverRevision: 9,
          toolsData: const {
            'work_log': {
              'version': 1,
              'data': {
                'tasks': [
                  {'id': 1, 'title': 't1'},
                ],
              },
            },
          },
        );

      final service = SyncService(
        configService: configService,
        localStateService: localStateService,
        aiConfigService: aiConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        wifiService: _FakeWifiService(NetworkStatus.wifi),
        apiClient: api,
        toolProviders: [provider],
      );

      final ok = await service.sync();
      expect(ok, isTrue);
      expect(provider.importCalls, 1);
      expect(provider.lastImported?['data'], isA<Map<String, dynamic>>());
      expect(configService.config?.lastServerRevision, 9);
      expect(configService.config?.lastSyncTime?.millisecondsSinceEpoch, 1000);
    });

    test('服务端返回 use_client 时，不导入数据，仅更新游标', () async {
      final provider = _FakeToolSyncProvider(
        toolId: 'work_log',
        exported: const {
          'version': 1,
          'data': {
            'tasks': [
              {'id': 1, 'title': 'local'},
            ],
          },
        },
      );

      final api = _FakeSyncApiClient()
        ..v2Response = SyncResponseV2(
          success: true,
          decision: SyncDecision.useClient,
          serverTime: DateTime.fromMillisecondsSinceEpoch(2000),
          serverRevision: 10,
          toolsData: null,
        );

      final service = SyncService(
        configService: configService,
        localStateService: localStateService,
        aiConfigService: aiConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        wifiService: _FakeWifiService(NetworkStatus.mobile),
        apiClient: api,
        toolProviders: [provider],
      );

      final ok = await service.sync();
      expect(ok, isTrue);
      expect(provider.importCalls, 0);
      expect(configService.config?.lastServerRevision, 10);
      expect(configService.config?.lastSyncTime?.millisecondsSinceEpoch, 2000);
    });

    test('本地无数据时，请求携带 client_is_empty=true（避免服务端被空覆盖）', () async {
      final provider = _FakeToolSyncProvider(
        toolId: 'work_log',
        exported: const {
          'version': 1,
          'data': {'tasks': []},
        },
      );

      final api = _FakeSyncApiClient()
        ..v2Response = SyncResponseV2(
          success: true,
          decision: SyncDecision.noop,
          serverTime: DateTime.fromMillisecondsSinceEpoch(3000),
          serverRevision: 11,
          toolsData: null,
        );

      final service = SyncService(
        configService: configService,
        localStateService: localStateService,
        aiConfigService: aiConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        wifiService: _FakeWifiService(NetworkStatus.wifi),
        apiClient: api,
        toolProviders: [provider],
      );

      final ok = await service.sync();
      expect(ok, isTrue);
      expect(api.lastRequestV2?.clientState.clientIsEmpty, isTrue);
    });

    test('服务端不支持 v2（404）时，回退到 v1 /sync', () async {
      final provider = _FakeToolSyncProvider(
        toolId: 'work_log',
        exported: const {
          'version': 1,
          'data': {
            'tasks': [
              {'id': 1},
            ],
          },
        },
      );

      final api = _FakeSyncApiClient()
        ..v2Exception = const SyncApiException(
          statusCode: 404,
          message: 'not found',
        )
        ..v1Response = SyncResponse(
          success: true,
          serverTime: DateTime.fromMillisecondsSinceEpoch(4000),
          toolsData: const {
            'work_log': {
              'version': 1,
              'data': {'tasks': []},
            },
          },
        );

      final service = SyncService(
        configService: configService,
        localStateService: localStateService,
        aiConfigService: aiConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        wifiService: _FakeWifiService(NetworkStatus.wifi),
        apiClient: api,
        toolProviders: [provider],
      );

      final ok = await service.sync();
      expect(ok, isTrue);
      expect(api.lastRequestV1, isNotNull);
      expect(provider.importCalls, 1);
    });

    test('请求应包含 app_config 快照（与备份配置段同构）', () async {
      final api = _FakeSyncApiClient()
        ..v2Response = SyncResponseV2(
          success: true,
          decision: SyncDecision.noop,
          serverTime: DateTime.fromMillisecondsSinceEpoch(5000),
          serverRevision: 12,
          toolsData: null,
        );

      await aiConfigService.save(
        const AiConfig(
          baseUrl: 'https://api.example.com',
          apiKey: 'k',
          model: 'm',
          temperature: 0.7,
          maxOutputTokens: 128,
        ),
      );

      await aiCallHistoryService.addRecord(
        source: const AiCallSource(
          toolId: 'work_log',
          toolName: '工作记录',
          featureId: 'voice_to_intent',
          featureName: '语音解析',
        ),
        model: 'gpt-4o-mini',
        prompt: 'prompt-sync',
        response: 'response-sync',
      );

      final service = SyncService(
        configService: configService,
        localStateService: localStateService,
        aiConfigService: aiConfigService,
        aiCallHistoryService: aiCallHistoryService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        wifiService: _FakeWifiService(NetworkStatus.wifi),
        apiClient: api,
        toolProviders: const [],
      );

      final ok = await service.sync();
      expect(ok, isTrue);
      final toolsData = api.lastRequestV2?.toolsData;
      expect(toolsData, isNotNull);
      expect(toolsData!.containsKey('app_config'), isTrue);
      final app = toolsData['app_config']!;
      expect(app['version'], 1);
      expect((app['updated_at_ms'] as num?)?.toInt(), greaterThan(0));
      final data = app['data'] as Map<String, dynamic>;
      expect(data.containsKey('ai_config'), isTrue);
      expect(data.containsKey('sync_config'), isTrue);
      expect(data.containsKey('obj_store_config'), isTrue);
      expect(data.containsKey('obj_store_secrets'), isTrue);
      expect(data.containsKey('settings'), isTrue);
      expect(data.containsKey('ai_call_history'), isTrue);
      final history = data['ai_call_history'] as Map<String, dynamic>;
      expect(history['records'], isA<List<dynamic>>());
    });

    test('服务端返回 use_server 且包含 app_config 时，应还原配置并更新配置时间戳', () async {
      final api = _FakeSyncApiClient()
        ..v2Response = SyncResponseV2(
          success: true,
          decision: SyncDecision.useServer,
          serverTime: DateTime.fromMillisecondsSinceEpoch(6000),
          serverRevision: 13,
          toolsData: const {
            'app_config': {
              'version': 1,
              'updated_at_ms': 9999999999999,
              'data': {
                'ai_config': {
                  'baseUrl': 'https://api.server.com',
                  'apiKey': 'k_server',
                  'model': 'm_server',
                  'temperature': 0.9,
                  'maxOutputTokens': 256,
                },
                'sync_config': null,
                'obj_store_config': null,
                'obj_store_secrets': null,
                'settings': {
                  'default_tool_id': null,
                  'tool_order': [],
                  'hidden_tool_ids': [],
                },
                'ai_call_history': {
                  'retention_limit': 10,
                  'records': [
                    {
                      'id': 'sync_history_1',
                      'source': {
                        'toolId': 'work_log',
                        'toolName': '工作记录',
                        'featureId': 'generate_summary',
                        'featureName': '生成总结',
                      },
                      'model': 'gpt-4o-mini',
                      'prompt': 'prompt-from-server',
                      'response': 'response-from-server',
                      'createdAt': 1760000000000,
                    },
                  ],
                },
              },
            },
          },
        );

      final service = SyncService(
        configService: configService,
        localStateService: localStateService,
        aiConfigService: aiConfigService,
        aiCallHistoryService: aiCallHistoryService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        wifiService: _FakeWifiService(NetworkStatus.wifi),
        apiClient: api,
        toolProviders: const [],
      );

      final ok = await service.sync();
      expect(ok, isTrue);
      expect(aiConfigService.config?.model, 'm_server');
      expect(aiConfigService.config?.apiKey, 'k_server');
      expect(aiCallHistoryService.retentionLimit, 10);
      expect(aiCallHistoryService.records.length, 1);
      expect(aiCallHistoryService.records.first.prompt, 'prompt-from-server');

      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(AppConfigUpdatedAt.storageKey);
      expect(ts, 9999999999999);
    });

    test('任一工具导出失败时应中止同步，避免不完整快照覆盖服务端', () async {
      final provider = _ThrowingToolSyncProvider(toolId: 'work_log');

      final api = _FakeSyncApiClient()
        ..v2Response = SyncResponseV2(
          success: true,
          decision: SyncDecision.noop,
          serverTime: DateTime.fromMillisecondsSinceEpoch(7000),
          serverRevision: 14,
          toolsData: null,
        );

      final service = SyncService(
        configService: configService,
        localStateService: localStateService,
        aiConfigService: aiConfigService,
        settingsService: settingsService,
        objStoreConfigService: objStoreConfigService,
        wifiService: _FakeWifiService(NetworkStatus.wifi),
        apiClient: api,
        toolProviders: [provider],
      );

      final ok = await service.sync();
      expect(ok, isFalse);
      expect(api.lastRequestV2, isNull);
      expect(service.lastError, isNotNull);
      expect(service.lastError!, contains('work_log'));
      expect(service.lastError!, contains('导出'));
    });
  });
}
