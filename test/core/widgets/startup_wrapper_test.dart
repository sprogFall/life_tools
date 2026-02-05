import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/sync/models/sync_config.dart';
import 'package:life_tools/core/sync/models/sync_force_decision.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:life_tools/core/sync/services/sync_service.dart';
import 'package:life_tools/core/widgets/ios26_toast.dart';
import 'package:life_tools/core/widgets/startup_wrapper.dart';
import 'package:provider/provider.dart';

// 手动 Mock

class MockSyncConfigService extends ChangeNotifier implements SyncConfigService {
  SyncConfig? _config;
  
  @override
  SyncConfig? get config => _config;

  void setConfig(SyncConfig? config) {
    _config = config;
    notifyListeners();
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockSyncService extends ChangeNotifier implements SyncService {
  bool syncCalled = false;
  bool syncResult = true;
  String? _lastError;

  @override
  String? get lastError => _lastError;

  // 模拟错误设置
  set error(String? value) => _lastError = value;

  @override
  Future<bool> sync({
    SyncTrigger trigger = SyncTrigger.manual,
    SyncForceDecision? forceDecision,
  }) async {
    syncCalled = true;
    return syncResult;
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockToastService extends ChangeNotifier implements ToastService {
  String? lastSuccessMessage;
  String? lastErrorMessage;

  @override
  void showSuccess(String message, {Duration duration = const Duration(seconds: 2)}) {
    lastSuccessMessage = message;
    notifyListeners();
  }

  @override
  void showError(String message, {Duration duration = const Duration(seconds: 2)}) {
    lastErrorMessage = message;
    notifyListeners();
  }
  
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('StartupWrapper 当 autoSyncOnStartup=true 时应触发同步并显示成功 Toast', (tester) async {
    final mockSyncConfigService = MockSyncConfigService();
    final config = SyncConfig(
        userId: 'test_user',
        networkType: SyncNetworkType.public,
        serverUrl: 'http://localhost',
        serverPort: 8080,
        customHeaders: {},
        allowedWifiNames: [],
        autoSyncOnStartup: true,
    );
    mockSyncConfigService.setConfig(config);

    final mockSyncService = MockSyncService();
    mockSyncService.syncResult = true;
    
    final mockToastService = MockToastService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SyncConfigService>.value(value: mockSyncConfigService),
          ChangeNotifierProvider<SyncService>.value(value: mockSyncService),
          ChangeNotifierProvider<ToastService>.value(value: mockToastService),
        ],
        child: const MaterialApp(
          home: StartupWrapper(child: SizedBox()),
        ),
      ),
    );

    // 初始等待
    await tester.pump(const Duration(milliseconds: 500)); 
    expect(mockSyncService.syncCalled, false);

    // 等待足够时间触发 delayed
    await tester.pump(const Duration(seconds: 2)); 
    await tester.pump(); // 处理 microtasks

    expect(mockSyncService.syncCalled, true);
    expect(mockToastService.lastSuccessMessage, '自动同步成功');
  });

  testWidgets('StartupWrapper 当同步失败时应显示错误 Toast', (tester) async {
    final mockSyncConfigService = MockSyncConfigService();
    final config = SyncConfig(
        userId: 'test_user',
        networkType: SyncNetworkType.public,
        serverUrl: 'http://localhost',
        serverPort: 8080,
        customHeaders: {},
        allowedWifiNames: [],
        autoSyncOnStartup: true,
    );
    mockSyncConfigService.setConfig(config);

    final mockSyncService = MockSyncService();
    mockSyncService.syncResult = false;
    mockSyncService.error = '网络错误';
    
    final mockToastService = MockToastService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SyncConfigService>.value(value: mockSyncConfigService),
          ChangeNotifierProvider<SyncService>.value(value: mockSyncService),
          ChangeNotifierProvider<ToastService>.value(value: mockToastService),
        ],
        child: const MaterialApp(
          home: StartupWrapper(child: SizedBox()),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(mockSyncService.syncCalled, true);
    expect(mockToastService.lastErrorMessage, '自动同步失败: 网络错误');
  });

  testWidgets('StartupWrapper 启动自动同步：私网模式但未连接 WiFi 时不应提示失败 Toast', (tester) async {
    final mockSyncConfigService = MockSyncConfigService();
    final config = SyncConfig(
        userId: 'test_user',
        networkType: SyncNetworkType.privateWifi,
        serverUrl: 'http://localhost',
        serverPort: 8080,
        customHeaders: {},
        allowedWifiNames: ['HomeWifi'],
        autoSyncOnStartup: true,
    );
    mockSyncConfigService.setConfig(config);

    final mockSyncService = MockSyncService();
    mockSyncService.syncResult = false;
    mockSyncService.error = '网络预检失败：私网模式下必须连接 WiFi（当前：mobile）';

    final mockToastService = MockToastService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SyncConfigService>.value(value: mockSyncConfigService),
          ChangeNotifierProvider<SyncService>.value(value: mockSyncService),
          ChangeNotifierProvider<ToastService>.value(value: mockToastService),
        ],
        child: const MaterialApp(
          home: StartupWrapper(child: SizedBox()),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(mockSyncService.syncCalled, true);
    expect(mockToastService.lastErrorMessage, isNull);
    expect(mockToastService.lastSuccessMessage, isNull);
  });

  testWidgets('StartupWrapper 当 autoSyncOnStartup=false 时不应触发同步', (tester) async {
    final mockSyncConfigService = MockSyncConfigService();
    final config = SyncConfig(
        userId: 'test_user',
        networkType: SyncNetworkType.public,
        serverUrl: 'http://localhost',
        serverPort: 8080,
        customHeaders: {},
        allowedWifiNames: [],
        autoSyncOnStartup: false,
    );
    mockSyncConfigService.setConfig(config);

    final mockSyncService = MockSyncService();
    final mockToastService = MockToastService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SyncConfigService>.value(value: mockSyncConfigService),
          ChangeNotifierProvider<SyncService>.value(value: mockSyncService),
          ChangeNotifierProvider<ToastService>.value(value: mockToastService),
        ],
        child: const MaterialApp(
          home: StartupWrapper(child: SizedBox()),
        ),
      ),
    );

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(mockSyncService.syncCalled, false);
  });
}
