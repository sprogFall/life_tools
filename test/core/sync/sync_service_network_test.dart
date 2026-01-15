import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/sync/models/sync_config.dart';
import 'package:life_tools/core/sync/models/sync_response.dart';
import 'package:life_tools/core/sync/services/sync_api_client.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:life_tools/core/sync/services/sync_service.dart';
import 'package:life_tools/core/sync/services/wifi_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeWifiService extends WifiService {
  final NetworkStatus status;
  final String? wifiName;

  _FakeWifiService({required this.status, required this.wifiName});

  @override
  Future<NetworkStatus> getNetworkStatus() async => status;

  @override
  Future<String?> getCurrentWifiName() async => wifiName;
}

class _NoopSyncApiClient extends SyncApiClient {
  _NoopSyncApiClient();

  @override
  Future<SyncResponse> sync({
    required SyncConfig config,
    required request,
    Duration timeout = const Duration(seconds: 120),
  }) {
    throw StateError('网络预检失败时不应调用 API');
  }

  @override
  void dispose() {}
}

void main() {
  group('SyncService - 网络预检', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('私网模式：WiFi 不在允许列表时，lastError 应包含明确原因而非笼统提示', () async {
      final configService = SyncConfigService();
      await configService.init();
      await configService.save(
        const SyncConfig(
          userId: 'u1',
          networkType: SyncNetworkType.privateWifi,
          serverUrl: 'sync.example.com',
          serverPort: 443,
          customHeaders: {},
          allowedWifiNames: ['AllowedWifi'],
        ),
      );

      final service = SyncService(
        configService: configService,
        wifiService: _FakeWifiService(
          status: NetworkStatus.wifi,
          wifiName: 'NotAllowedWifi',
        ),
        apiClient: _NoopSyncApiClient(),
      );

      final ok = await service.sync();
      expect(ok, isFalse);
      expect(service.lastError, isNotNull);
      expect(service.lastError!, contains('WiFi'));
      expect(service.lastError!, isNot(contains('当前网络条件不满足同步要求')));
    });

    test('私网模式：无法读取当前 WiFi 名称时，lastError 应提示可能原因', () async {
      final configService = SyncConfigService();
      await configService.init();
      await configService.save(
        const SyncConfig(
          userId: 'u1',
          networkType: SyncNetworkType.privateWifi,
          serverUrl: 'sync.example.com',
          serverPort: 443,
          customHeaders: {},
          allowedWifiNames: ['AllowedWifi'],
        ),
      );

      final service = SyncService(
        configService: configService,
        wifiService: _FakeWifiService(
          status: NetworkStatus.wifi,
          wifiName: null,
        ),
        apiClient: _NoopSyncApiClient(),
      );

      final ok = await service.sync();
      expect(ok, isFalse);
      expect(service.lastError, isNotNull);
      expect(service.lastError!, contains('无法获取'));
      expect(service.lastError!, contains('WiFi'));
    });
  });
}
