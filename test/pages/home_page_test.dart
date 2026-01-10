import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:life_tools/pages/home_page.dart';
import 'package:life_tools/core/services/settings_service.dart';
import 'package:life_tools/core/registry/tool_registry.dart';

void main() {
  group('HomePage', () {
    late SettingsService mockSettingsService;

    setUp(() {
      ToolRegistry.instance.registerAll();
      mockSettingsService = SettingsService();
    });

    testWidgets('应该显示欢迎标题', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsService>.value(
            value: mockSettingsService,
            child: const HomePage(),
          ),
        ),
      );

      expect(find.text('生活助手'), findsOneWidget);
      expect(find.text('欢迎使用生活助手'), findsOneWidget);
    });

    testWidgets('应该显示设置按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsService>.value(
            value: mockSettingsService,
            child: const HomePage(),
          ),
        ),
      );

      expect(find.byIcon(Icons.settings), findsOneWidget);
    });

    testWidgets('应该显示工具卡片', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<SettingsService>.value(
            value: mockSettingsService,
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

    testWidgets('点击设置按钮应该打开设置对话框', (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsService>.value(
          value: mockSettingsService,
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.settings));
      await tester.pumpAndSettle();

      expect(find.text('设置'), findsOneWidget);
      expect(find.text('默认打开工具:'), findsOneWidget);
    });
  });
}
