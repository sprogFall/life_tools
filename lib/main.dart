import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
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

class MyApp extends StatefulWidget {
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
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late StreamSubscription<List<SharedMediaFile>> _sharedFilesSubscription;
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initSharing();
  }

  void _initSharing() {
    // 监听分享的文件（app在后台时）
    _sharedFilesSubscription = ReceiveSharingIntent.instance
        .getMediaStream()
        .listen(
          _handleSharedFiles,
          onError: (err) {
            debugPrint('接收分享文件出错: $err');
          },
        );

    // 获取初始分享的文件（app被分享唤起时）
    ReceiveSharingIntent.instance.getInitialMedia().then(_handleSharedFiles);
  }

  void _handleSharedFiles(List<SharedMediaFile> files) {
    if (files.isEmpty) return;

    // 找到第一个 .txt 或 .json 文件
    final backupFile = files.firstWhere(
      (file) =>
          file.path.toLowerCase().endsWith('.txt') ||
          file.path.toLowerCase().endsWith('.json'),
      orElse: () => files.first,
    );

    // 导航到备份还原页面并自动导入
    if (navigatorKey.currentContext != null) {
      _navigateToBackupRestore(backupFile.path);
    } else {
      // 如果context还不可用，延迟执行
      Future.delayed(const Duration(milliseconds: 500), () {
        if (navigatorKey.currentContext != null) {
          _navigateToBackupRestore(backupFile.path);
        }
      });
    }
  }

  void _navigateToBackupRestore(String filePath) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    // 导入到备份还原页面需要创建一个特殊的入口
    // 这里我们需要添加一个导入服务来处理
    SharedFileImportService.instance.setSharedFilePath(filePath);

    // 弹出提示
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('检测到备份文件'),
        content: const Text('是否要导入此备份文件？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () {
              Navigator.of(context).pop();
              // 导航到备份还原页面
              Navigator.of(context).pushNamed('/backup-restore');
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sharedFilesSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.settingsService),
        ChangeNotifierProvider.value(value: widget.aiConfigService),
        ChangeNotifierProvider.value(value: widget.syncConfigService),
        ChangeNotifierProvider.value(value: widget.syncService),
        Provider<AiService>(
          create: (_) => AiService(configService: widget.aiConfigService),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
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
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        home: _buildInitialPage(),
      ),
    );
  }

  Widget _buildInitialPage() {
    // 检查是否有默认工具设置
    final defaultTool = widget.settingsService.getDefaultTool();
    if (defaultTool != null) {
      return defaultTool.pageBuilder();
    }
    return const HomePage();
  }
}

// 用于临时存储分享的文件路径的单例服务
class SharedFileImportService {
  static final SharedFileImportService instance =
      SharedFileImportService._internal();

  SharedFileImportService._internal();

  String? _sharedFilePath;

  void setSharedFilePath(String? path) {
    _sharedFilePath = path;
  }

  String? getAndClearSharedFilePath() {
    final path = _sharedFilePath;
    _sharedFilePath = null;
    return path;
  }
}
