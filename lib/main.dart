import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/ai/ai_config_service.dart';
import 'core/ai/ai_service.dart';
import 'core/registry/tool_registry.dart';
import 'core/services/settings_service.dart';
import 'core/sync/services/sync_config_service.dart';
import 'core/sync/services/sync_service.dart';
import 'core/theme/ios26_theme.dart';
import 'pages/home_page.dart';

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

  runApp(
    MyApp(
      settingsService: settingsService,
      aiConfigService: aiConfigService,
      syncConfigService: syncConfigService,
      syncService: syncService,
    ),
  );
}

class MyApp extends StatelessWidget {
  final SettingsService settingsService;
  final AiConfigService aiConfigService;
  final SyncConfigService syncConfigService;
  final SyncService syncService;

  const MyApp({
    super.key,
    required this.settingsService,
    required this.aiConfigService,
    required this.syncConfigService,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsService),
        ChangeNotifierProvider.value(value: aiConfigService),
        ChangeNotifierProvider.value(value: syncConfigService),
        ChangeNotifierProvider.value(value: syncService),
        Provider<AiService>(
          create: (_) => AiService(configService: aiConfigService),
        ),
      ],
      child: MaterialApp(
        title: '生活助手',
        debugShowCheckedModeBanner: false,
        theme: IOS26Theme.lightTheme,
        scrollBehavior: const CupertinoScrollBehavior(),
        locale: const Locale('zh', 'CN'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        home: _buildInitialPage(),
      ),
    );
  }

  Widget _buildInitialPage() {
    // 检查是否有默认工具设置
    final defaultTool = settingsService.getDefaultTool();
    if (defaultTool != null) {
      return defaultTool.pageBuilder();
    }
    return const HomePage();
  }
}
