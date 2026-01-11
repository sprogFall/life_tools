import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_tools/pages/home_page.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/core/registry/tool_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('HomePage', () {
    late SettingsService mockSettingsService;
    late AiConfigService aiConfigService;

    setUp(() async {
      ToolRegistry.instance.registerAll();
      mockSettingsService = SettingsService();
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      aiConfigService = AiConfigService();
      await aiConfigService.init();
    });

    testWidgets('应该显示应用标题', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsService>.value(
                value: mockSettingsService,
              ),
              ChangeNotifierProvider<AiConfigService>.value(
                value: aiConfigService,
              ),
            ],
            child: const HomePage(),
          ),
        ),
      );

      expect(find.text('生活助手'), findsOneWidget);
    });

    testWidgets('应该显示欢迎卡片', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsService>.value(
                value: mockSettingsService,
              ),
              ChangeNotifierProvider<AiConfigService>.value(
                value: aiConfigService,
              ),
            ],
            child: const HomePage(),
          ),
        ),
      );

      expect(find.text('欢迎回来'), findsOneWidget);
    });

    testWidgets('应该显示设置按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsService>.value(
                value: mockSettingsService,
              ),
              ChangeNotifierProvider<AiConfigService>.value(
                value: aiConfigService,
              ),
            ],
            child: const HomePage(),
          ),
        ),
      );

      expect(find.byIcon(CupertinoIcons.gear), findsOneWidget);
    });

    testWidgets('应该显示工具卡片', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<SettingsService>.value(
                value: mockSettingsService,
              ),
              ChangeNotifierProvider<AiConfigService>.value(
                value: aiConfigService,
              ),
            ],
            child: const HomePage(),
          ),
        ),
      );

      // 检查是否显示了注册的工具
      expect(find.text('工作记录'), findsOneWidget);
      expect(find.text('复盘笔记'), findsOneWidget);
      expect(find.text('日常开销'), findsOneWidget);
      expect(find.text('收入记录'), findsOneWidget);
    });

    testWidgets('点击设置按钮应该打开设置弹出层', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SettingsService>.value(
              value: mockSettingsService,
            ),
            ChangeNotifierProvider<AiConfigService>.value(
              value: aiConfigService,
            ),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      await tester.tap(find.byIcon(CupertinoIcons.gear));
      await tester.pumpAndSettle();

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('默认打开工具'), findsOneWidget);
    });
  });
}
