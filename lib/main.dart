import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/registry/tool_registry.dart';
import 'core/services/settings_service.dart';
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

  runApp(MyApp(settingsService: settingsService));
}

class MyApp extends StatelessWidget {
  final SettingsService settingsService;

  const MyApp({super.key, required this.settingsService});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: settingsService,
      child: MaterialApp(
        title: '生活助手',
        debugShowCheckedModeBanner: false,
        theme: IOS26Theme.lightTheme,
        scrollBehavior: const CupertinoScrollBehavior(),
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
