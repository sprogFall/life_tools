import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:life_tools/core/sync/services/sync_local_state_service.dart';
import 'package:life_tools/core/sync/services/sync_service.dart';
import 'package:life_tools/core/sync/services/wifi_service.dart';
import 'package:life_tools/core/widgets/ios26_toast.dart';
import 'package:life_tools/core/sync/pages/sync_settings_page.dart';
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

class _MockSyncService extends ChangeNotifier implements SyncService {
  @override
  SyncState get state => SyncState.idle;

  @override
  String? get lastError => null;

  @override
  bool get isSyncing => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SyncSettingsPage 在英文环境下应展示英文文案', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final configService = SyncConfigService();
    await configService.init();
    final localStateService = SyncLocalStateService();
    await localStateService.init();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SyncConfigService>.value(value: configService),
          ChangeNotifierProvider<SyncLocalStateService>.value(
            value: localStateService,
          ),
          ChangeNotifierProvider<SyncService>.value(value: _MockSyncService()),
          ChangeNotifierProvider<ToastService>.value(value: ToastService()),
          Provider<WifiService>.value(value: _FakeWifiService(NetworkStatus.wifi)),
        ],
        child: const TestAppWrapper(
          locale: Locale('en', 'US'),
          child: SyncSettingsPage(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Data Sync'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Public'), findsOneWidget);
    expect(find.text('Private'), findsOneWidget);
  });
}
