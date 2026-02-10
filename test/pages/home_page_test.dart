import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/core/messages/message_repository.dart';
import 'package:life_tools/core/messages/message_service.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/secret_store/in_memory_secret_store.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/core/sync/services/sync_config_service.dart';
import 'package:life_tools/core/sync/services/sync_local_state_service.dart';
import 'package:life_tools/core/sync/services/sync_service.dart';
import 'package:life_tools/core/sync/models/sync_config.dart';
import 'package:life_tools/core/sync/services/wifi_service.dart';
import 'package:life_tools/l10n/app_localizations.dart';
import 'package:life_tools/pages/home_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];

  int get pushedPageRoutesCount => pushedRoutes.whereType<PageRoute>().length;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}

class _FakeWifiService extends WifiService {
  final NetworkStatus status;
  final String? wifiName;

  _FakeWifiService({required this.status, required this.wifiName});

  @override
  Future<NetworkStatus> getNetworkStatus() async => status;

  @override
  Future<String?> getCurrentWifiName() async => wifiName;
}

void main() {
  group('HomePage', () {
    late SettingsService mockSettingsService;
    late AiConfigService aiConfigService;
    late ObjStoreConfigService objStoreConfigService;
    late SyncConfigService syncConfigService;
    late SyncLocalStateService syncLocalStateService;
    late SyncService syncService;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});

      ToolRegistry.instance.registerAll();
      mockSettingsService = SettingsService();

      aiConfigService = AiConfigService();
      await aiConfigService.init();

      objStoreConfigService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await objStoreConfigService.init();

      syncConfigService = SyncConfigService();
      await syncConfigService.init();

      syncLocalStateService = SyncLocalStateService();
      await syncLocalStateService.init();

      syncService = SyncService(
        configService: syncConfigService,
        localStateService: syncLocalStateService,
        aiConfigService: aiConfigService,
        settingsService: mockSettingsService,
        objStoreConfigService: objStoreConfigService,
      );
    });

    Future<({Database db, MessageService messageService})> createMessageService(
      WidgetTester tester,
    ) async {
      late Database db;
      late MessageService messageService;
      await tester.runAsync(() async {
        db = await openDatabase(
          inMemoryDatabasePath,
          version: DatabaseSchema.version,
          onConfigure: DatabaseSchema.onConfigure,
          onCreate: DatabaseSchema.onCreate,
          onUpgrade: DatabaseSchema.onUpgrade,
        );
        messageService = MessageService(
          repository: MessageRepository.withDatabase(db),
        );
        await messageService.init();
      });
      addTearDown(() async {
        await tester.runAsync(() async => db.close());
      });
      return (db: db, messageService: messageService);
    }

    Widget wrap(
      Widget child,
      MessageService messageService, {
      List<NavigatorObserver> navigatorObservers = const [],
    }) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SettingsService>.value(
            value: mockSettingsService,
          ),
          ChangeNotifierProvider<AiConfigService>.value(value: aiConfigService),
          ChangeNotifierProvider<ObjStoreConfigService>.value(
            value: objStoreConfigService,
          ),
          ChangeNotifierProvider<SyncConfigService>.value(
            value: syncConfigService,
          ),
          ChangeNotifierProvider<SyncLocalStateService>.value(
            value: syncLocalStateService,
          ),
          ChangeNotifierProvider<SyncService>.value(value: syncService),
          Provider<WifiService>.value(
            value: _FakeWifiService(
              status: NetworkStatus.offline,
              wifiName: null,
            ),
          ),
          ChangeNotifierProvider<MessageService>.value(value: messageService),
        ],
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
          navigatorObservers: navigatorObservers,
        ),
      );
    }

    testWidgets('应渲染应用标题', (WidgetTester tester) async {
      final deps = await createMessageService(tester);
      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));
      expect(find.text('小蜜'), findsOneWidget);
    });

    testWidgets('无消息时应展示空态文案', (WidgetTester tester) async {
      final deps = await createMessageService(tester);
      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));
      expect(find.text('当前暂时没有新的消息'), findsOneWidget);
    });

    testWidgets('有未读消息时应展示消息内容', (WidgetTester tester) async {
      final deps = await createMessageService(tester);
      await tester.runAsync(() async {
        await deps.messageService.upsertMessage(
          toolId: 'work_log',
          title: '工作记录',
          body: '这是一条测试消息',
          createdAt: DateTime(2026, 1, 1, 9),
        );
      });

      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));
      await tester.pump();

      expect(find.text('这是一条测试消息'), findsOneWidget);
    });

    testWidgets('应展示设置入口', (WidgetTester tester) async {
      final deps = await createMessageService(tester);
      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));
      expect(find.byIcon(CupertinoIcons.gear), findsOneWidget);
    });

    testWidgets('应展示工具入口', (WidgetTester tester) async {
      final deps = await createMessageService(tester);
      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));
      expect(find.text('工作记录'), findsOneWidget);
      expect(find.text('标签管理'), findsOneWidget);
    });

    testWidgets('设置弹出层应展示设置项', (tester) async {
      final deps = await createMessageService(tester);
      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));

      await tester.tap(find.byIcon(CupertinoIcons.gear));
      await tester.pumpAndSettle();

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('工具管理'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('settings_theme_mode_row')),
        findsOneWidget,
      );
    });

    testWidgets('设置弹出层可切换深色/跟随系统模式', (tester) async {
      final deps = await createMessageService(tester);
      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));

      await tester.tap(find.byIcon(CupertinoIcons.gear));
      await tester.pumpAndSettle();

      expect(mockSettingsService.themeMode, ThemeMode.light);

      await tester.tap(find.byKey(const ValueKey('settings_theme_mode_row')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('settings_theme_mode_dark_action')),
      );
      await tester.pumpAndSettle();

      expect(mockSettingsService.themeMode, ThemeMode.dark);

      await tester.tap(find.byKey(const ValueKey('settings_theme_mode_row')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('settings_theme_mode_system_action')),
      );
      await tester.pumpAndSettle();

      expect(mockSettingsService.themeMode, ThemeMode.system);
    });

    testWidgets('设置弹出层中 AI 模型名过长应使用省略号', (tester) async {
      final deps = await createMessageService(tester);
      await aiConfigService.save(
        const AiConfig(
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'test-key',
          model:
              'this-is-a-very-very-very-very-very-long-model-name-for-testing',
          temperature: 0.7,
          maxOutputTokens: 1024,
        ),
      );

      await tester.pumpWidget(wrap(const HomePage(), deps.messageService));
      await tester.tap(find.byIcon(CupertinoIcons.gear));
      await tester.pumpAndSettle();

      final modelText = find.text(
        'this-is-a-very-very-very-very-very-long-model-name-for-testing',
      );
      expect(modelText, findsOneWidget);

      final widget = tester.widget<Text>(modelText);
      expect(widget.maxLines, 1);
      expect(widget.overflow, TextOverflow.ellipsis);
    });

    testWidgets('连续点击标题 6 次未配置时应弹窗并可跳转到同步配置', (tester) async {
      final deps = await createMessageService(tester);
      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(
        wrap(
          const HomePage(),
          deps.messageService,
          navigatorObservers: [observer],
        ),
      );

      final initialPagePushCount = observer.pushedPageRoutesCount;
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.text('小蜜'));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      expect(find.text('同步未配置'), findsOneWidget);
      expect(find.text('去配置'), findsOneWidget);
      expect(observer.pushedPageRoutesCount, initialPagePushCount);

      await tester.tap(find.text('去配置'));
      await tester.pumpAndSettle();
      expect(observer.pushedPageRoutesCount, initialPagePushCount + 1);
    });

    testWidgets('连续点击标题 6 次已配置时应进入同步记录页', (tester) async {
      final deps = await createMessageService(tester);
      await syncConfigService.save(
        const SyncConfig(
          userId: 'u1',
          networkType: SyncNetworkType.public,
          serverUrl: 'http://127.0.0.1',
          serverPort: 8080,
          customHeaders: {},
          allowedWifiNames: [],
          autoSyncOnStartup: false,
        ),
      );

      final observer = _RecordingNavigatorObserver();
      await tester.pumpWidget(
        wrap(
          const HomePage(),
          deps.messageService,
          navigatorObservers: [observer],
        ),
      );

      final initialPagePushCount = observer.pushedPageRoutesCount;
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.text('小蜜'));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      expect(find.text('同步未配置'), findsNothing);
      expect(observer.pushedPageRoutesCount, initialPagePushCount + 1);
      expect(find.textContaining('网络预检失败'), findsOneWidget);
    });
  });
}
