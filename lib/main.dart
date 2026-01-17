import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/ai/ai_config_service.dart';
import 'core/ai/ai_service.dart';
import 'core/backup/pages/backup_restore_page.dart';
import 'core/backup/services/receive_share_service.dart';
import 'core/messages/message_service.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/registry/tool_registry.dart';
import 'core/services/settings_service.dart';
import 'core/sync/services/sync_config_service.dart';
import 'core/sync/services/sync_service.dart';
import 'core/tags/tag_service.dart';
import 'core/theme/ios26_theme.dart';
import 'pages/home_page.dart';
import 'tools/stockpile_assistant/services/stockpile_reminder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 在 Windows 平台上初始化 sqflite FFI
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 注册所有工具
  ToolRegistry.instance.registerAll();

  // 初始化设置服务
  final settingsService = SettingsService();
  await settingsService.init();

  final aiConfigService = AiConfigService();
  await aiConfigService.init();

  // 初始化同步服务
  final syncConfigService = SyncConfigService();
  await syncConfigService.init();

  final syncService = SyncService(configService: syncConfigService);

  // 自动同步（在后台静默执行，不阻塞启动）
  if (syncConfigService.config?.autoSyncOnStartup ?? false) {
    Future.microtask(() => syncService.sync());
  }

  final notificationService =
      (Platform.isAndroid || Platform.isIOS) ? LocalNotificationService() : null;
  await notificationService?.init();

  final messageService = MessageService(
    notificationService: notificationService,
  );
  await messageService.init();

  // 启动时检查囤货临期/过期提醒（写入首页消息并推送系统通知）
  Future.microtask(
    () => StockpileReminderService().pushDueReminders(
      messageService: messageService,
    ),
  );

  runApp(
    MyApp(
      settingsService: settingsService,
      aiConfigService: aiConfigService,
      syncConfigService: syncConfigService,
      syncService: syncService,
      messageService: messageService,
    ),
  );
}

class MyApp extends StatefulWidget {
  final SettingsService settingsService;
  final AiConfigService aiConfigService;
  final SyncConfigService syncConfigService;
  final SyncService syncService;
  final MessageService messageService;

  const MyApp({
    super.key,
    required this.settingsService,
    required this.aiConfigService,
    required this.syncConfigService,
    required this.syncService,
    required this.messageService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _receiveShareService = ReceiveShareService();
  DateTime _lastStockpileReminderCheckDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 仅在移动端初始化接收分享
    if (Platform.isAndroid || Platform.isIOS) {
      _receiveShareService.init(_handleReceivedShare);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _receiveShareService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastDay = DateTime(
      _lastStockpileReminderCheckDay.year,
      _lastStockpileReminderCheckDay.month,
      _lastStockpileReminderCheckDay.day,
    );
    if (!today.isAfter(lastDay)) return;
    _lastStockpileReminderCheckDay = today;

    Future.microtask(
      () => StockpileReminderService().pushDueReminders(
        messageService: widget.messageService,
      ),
    );
  }

  void _handleReceivedShare(String jsonText) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigatorKey.currentState?.push(
        CupertinoPageRoute(
          builder: (_) => BackupRestorePage(initialJson: jsonText),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.settingsService),
        ChangeNotifierProvider.value(value: widget.aiConfigService),
        ChangeNotifierProvider.value(value: widget.syncConfigService),
        ChangeNotifierProvider.value(value: widget.syncService),
        ChangeNotifierProvider.value(value: widget.messageService),
        ChangeNotifierProvider<TagService>(create: (_) => TagService()),
        Provider<AiService>(
          create: (_) => AiService(configService: widget.aiConfigService),
        ),
      ],
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: '小蜜',
        debugShowCheckedModeBanner: false,
        theme: IOS26Theme.lightTheme,
        scrollBehavior: const CupertinoScrollBehavior(),
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        home: _buildInitialPage(),
      ),
    );
  }

  Widget _buildInitialPage() {
    final defaultTool = widget.settingsService.getDefaultTool();
    if (defaultTool != null) {
      return defaultTool.pageBuilder();
    }
    return const HomePage();
  }
}
