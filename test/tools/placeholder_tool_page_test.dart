import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/placeholder_tool_page.dart';

void main() {
  group('PlaceholderToolPage', () {
    testWidgets('应该显示工具名称', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PlaceholderToolPage(toolName: '测试工具'),
        ),
      );

      expect(find.text('测试工具'), findsOneWidget);
      expect(find.text('测试工具 功能开发中...'), findsOneWidget);
    });

    testWidgets('应该显示建设中图标', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PlaceholderToolPage(toolName: '测试工具'),
        ),
      );

      expect(find.byIcon(Icons.construction), findsOneWidget);
    });

    testWidgets('应该显示首页按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PlaceholderToolPage(toolName: '测试工具'),
        ),
      );

      expect(find.byIcon(Icons.home), findsOneWidget);
    });
  });
}
