import 'package:flutter/cupertino.dart';
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

      // 新 UI 中工具名称出现在标题栏和内容区域
      expect(find.text('测试工具'), findsWidgets);
    });

    testWidgets('应该显示开发中提示', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PlaceholderToolPage(toolName: '测试工具'),
        ),
      );

      expect(find.text('功能开发中，敬请期待...'), findsOneWidget);
    });

    testWidgets('应该显示锤子图标', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PlaceholderToolPage(toolName: '测试工具'),
        ),
      );

      expect(find.byIcon(CupertinoIcons.hammer), findsOneWidget);
    });

    testWidgets('应该显示返回首页按钮', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PlaceholderToolPage(toolName: '测试工具'),
        ),
      );

      expect(find.text('返回首页'), findsOneWidget);
      expect(find.text('首页'), findsOneWidget);
    });
  });
}
