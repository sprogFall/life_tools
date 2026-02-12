import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/sync/pages/sync_records_page.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:life_tools/core/sync/services/wifi_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_helpers/test_app_wrapper.dart';

class _FakeWifiService extends WifiService {
  final NetworkStatus status;

  _FakeWifiService(this.status);

  @override
  Future<NetworkStatus> getNetworkStatus() async => status;

  @override
  Future<String?> getCurrentWifiName() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SyncRecordsPage 在英文环境下应展示英文文案', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final configService = SyncConfigService();
    await configService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SyncConfigService>.value(value: configService),
          Provider<WifiService>.value(
            value: _FakeWifiService(NetworkStatus.wifi),
          ),
        ],
        child: const TestAppWrapper(
          locale: Locale('en', 'US'),
          child: SyncRecordsPage(),
        ),
      ),
    );

    // 等待首帧后的 _refresh() 执行（配置为空会直接展示错误卡片）
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('Sync Records'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.textContaining('Sync config'), findsOneWidget);
  });
}
