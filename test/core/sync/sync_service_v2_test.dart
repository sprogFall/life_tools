import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/sync/interfaces/tool_sync_provider.dart';
import 'package:life_tools/core/sync/models/sync_config.dart';
import 'package:life_tools/core/sync/models/sync_request.dart';
import 'package:life_tools/core/sync/models/sync_request_v2.dart';
import 'package:life_tools/core/sync/models/sync_response.dart';
import 'package:life_tools/core/sync/models/sync_response_v2.dart';
import 'package:life_tools/core/sync/services/sync_api_client.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:life_tools/core/sync/services/sync_service.dart';
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

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      configService = SyncConfigService();
      await configService.init();
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
        wifiService: _FakeWifiService(NetworkStatus.wifi),
        apiClient: api,
        toolProviders: [provider],
      );

      final ok = await service.sync();
      expect(ok, isTrue);
      expect(api.lastRequestV1, isNotNull);
      expect(provider.importCalls, 1);
    });
  });
}
