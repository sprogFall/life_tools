import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/sync/services/wifi_service.dart';

class _FakeWifiService extends WifiService {
  final NetworkStatus status;
  final String? wifiName;

  _FakeWifiService({
    required this.status,
    required this.wifiName,
  });

  @override
  Future<NetworkStatus> getNetworkStatus() async => status;

  @override
  Future<String?> getCurrentWifiName() async => wifiName;
}

void main() {
  group('WifiService', () {
    test('isWifiAllowed 应该对 SSID 做基础归一化（去引号/trim）', () async {
      final wifiService = _FakeWifiService(
        status: NetworkStatus.wifi,
        wifiName: 'MyWifi',
      );

      final ok = await wifiService.isWifiAllowed(['"MyWifi"', ' OtherWifi ']);
      expect(ok, isTrue);
    });
  });
}

