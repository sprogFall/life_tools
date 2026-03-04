import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer/tools/xiao_mi/ai/xiao_mi_prompt_resolver.dart';
import 'package:namer/tools/xiao_mi/widgets/chat_empty_state.dart';

void main() {
  group('ChatEmptyState', () {
    testWidgets('显示标题和副标题', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatEmptyState(
              title: '欢迎使用',
              subtitle: '我是你的AI助手',
              prompts: const [],
              onTapPrompt: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('欢迎使用'), findsOneWidget);
      expect(find.text('我是你的AI助手'), findsOneWidget);
    });

    testWidgets('显示快捷提示按钮', (tester) async {
      final prompts = [
        const XiaoMiQuickPrompt(
          id: 'test1',
          text: '测试提示1',
          description: '描述1',
        ),
        const XiaoMiQuickPrompt(
          id: 'test2',
          text: '测试提示2',
          description: '描述2',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatEmptyState(
              title: 'Test',
              subtitle: 'Test subtitle',
              prompts: prompts,
              onTapPrompt: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('测试提示1'), findsOneWidget);
      expect(find.text('测试提示2'), findsOneWidget);
    });

    testWidgets('点击快捷提示触发回调', (tester) async {
      XiaoMiQuickPrompt? tappedPrompt;
      const prompt = XiaoMiQuickPrompt(
        id: 'test',
        text: '点击我',
        description: '描述',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatEmptyState(
              title: 'Test',
              subtitle: 'Test subtitle',
              prompts: const [prompt],
              onTapPrompt: (p) => tappedPrompt = p,
            ),
          ),
        ),
      );

      await tester.tap(find.text('点击我'));
      await tester.pump();

      expect(tappedPrompt, isNotNull);
      expect(tappedPrompt!.id, 'test');
    });

    testWidgets('显示AI头像图标', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatEmptyState(
              title: 'Test',
              subtitle: 'Test',
              prompts: const [],
              onTapPrompt: (_) {},
            ),
          ),
        ),
      );

      // 验证头像容器存在（使用Cupertino图标）
      expect(find.byIcon(CupertinoIcons.bubble_left_bubble_right_fill), findsOneWidget);
    });
  });
}
