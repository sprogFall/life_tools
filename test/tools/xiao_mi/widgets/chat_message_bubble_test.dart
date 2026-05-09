import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/xiao_mi/models/xiao_mi_message.dart';
import 'package:life_tools/tools/xiao_mi/widgets/chat_message_bubble.dart';

import '../../../test_helpers/test_app_wrapper.dart';

void main() {
  group('ChatMessageBubble', () {
    final testDate = DateTime(2024, 1, 1);

    Widget wrapWidget(Widget child) {
      return TestAppWrapper(
        child: Scaffold(body: BackdropGroup(child: child)),
      );
    }

    testWidgets('用户消息显示右对齐绿色气泡', (tester) async {
      final message = XiaoMiMessage(
        id: 1,
        conversationId: 1,
        role: XiaoMiMessageRole.user,
        content: 'Hello',
        metadata: null,
        createdAt: testDate,
      );

      await tester.pumpWidget(
        wrapWidget(
          ChatMessageBubble(
            message: message,
            selectionMode: false,
            selected: false,
            onTap: () {},
            onLongPress: () {},
            onCopy: () {},
            onExport: () {},
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
      // 用户消息通过 Row mainAxisAlignment 实现右对齐
      final rowFinder = find.byType(Row);
      expect(rowFinder, findsWidgets);
    });

    testWidgets('AI消息显示左对齐并带头像', (tester) async {
      final message = XiaoMiMessage(
        id: 1,
        conversationId: 1,
        role: XiaoMiMessageRole.assistant,
        content: 'Hi there',
        metadata: null,
        createdAt: testDate,
      );

      await tester.pumpWidget(
        wrapWidget(
          ChatMessageBubble(
            message: message,
            selectionMode: false,
            selected: false,
            showAvatar: true,
            onTap: () {},
            onLongPress: () {},
            onCopy: () {},
            onExport: () {},
          ),
        ),
      );

      expect(find.text('Hi there'), findsOneWidget);
      // AI头像存在
      expect(find.byIcon(CupertinoIcons.bubble_left_fill), findsOneWidget);
    });

    testWidgets('选择模式显示选择图标', (tester) async {
      final message = XiaoMiMessage(
        id: 1,
        conversationId: 1,
        role: XiaoMiMessageRole.user,
        content: 'Test',
        metadata: null,
        createdAt: testDate,
      );

      await tester.pumpWidget(
        wrapWidget(
          ChatMessageBubble(
            message: message,
            selectionMode: true,
            selected: true,
            onTap: () {},
            onLongPress: () {},
            onCopy: () {},
            onExport: () {},
          ),
        ),
      );

      // 选中时显示勾选图标
      expect(
        find.byIcon(CupertinoIcons.check_mark_circled_solid),
        findsOneWidget,
      );
    });

    testWidgets('长按时触发 onLongPress', (tester) async {
      var longPressed = false;
      final message = XiaoMiMessage(
        id: 1,
        conversationId: 1,
        role: XiaoMiMessageRole.user,
        content: 'Long press me',
        metadata: null,
        createdAt: testDate,
      );

      await tester.pumpWidget(
        wrapWidget(
          ChatMessageBubble(
            message: message,
            selectionMode: false,
            selected: false,
            onTap: () {},
            onLongPress: () => longPressed = true,
            onCopy: () {},
            onExport: () {},
          ),
        ),
      );

      // 在气泡容器区域（非 SelectableText）执行长按
      final bubbleFinder = find.byType(ChatMessageBubble);
      final bubbleCenter = tester.getCenter(bubbleFinder);
      // 偏移到气泡边缘的 padding 区域避开 SelectableText 手势竞争
      await tester.longPressAt(Offset(bubbleCenter.dx + 80, bubbleCenter.dy));
      expect(longPressed, isTrue);
    });

    testWidgets('显示思考过程面板', (tester) async {
      final message = XiaoMiMessage(
        id: 1,
        conversationId: 1,
        role: XiaoMiMessageRole.assistant,
        content: 'Response',
        metadata: {'thinking': 'Let me think...'},
        createdAt: testDate,
      );

      await tester.pumpWidget(
        wrapWidget(
          ChatMessageBubble(
            message: message,
            selectionMode: false,
            selected: false,
            onTap: () {},
            onLongPress: () {},
            onCopy: () {},
            onExport: () {},
          ),
        ),
      );

      expect(find.text('思考过程'), findsOneWidget);
    });

    testWidgets('AI消息尾部显示 token 与耗时信息', (tester) async {
      final message = XiaoMiMessage(
        id: 7,
        conversationId: 1,
        role: XiaoMiMessageRole.assistant,
        content: 'Response',
        metadata: {
          'aiUsage': {
            'promptTokens': 1234,
            'completionTokens': 56,
            'totalTokens': 1290,
            'durationMs': 1234,
          },
        },
        createdAt: testDate,
      );

      await tester.pumpWidget(
        wrapWidget(
          ChatMessageBubble(
            message: message,
            selectionMode: false,
            selected: false,
            onTap: () {},
            onLongPress: () {},
            onCopy: () {},
            onExport: () {},
          ),
        ),
      );

      expect(find.text('上送 1,234'), findsOneWidget);
      expect(find.text('输出 56'), findsOneWidget);
      expect(find.text('总计 1,290'), findsOneWidget);
      expect(find.text('耗时 1.2s'), findsOneWidget);
    });

    testWidgets('AI消息耗时接近分钟边界时按四舍五入总秒数展示', (tester) async {
      final message = XiaoMiMessage(
        id: 9,
        conversationId: 1,
        role: XiaoMiMessageRole.assistant,
        content: 'Response',
        metadata: {
          'aiUsage': {'durationMs': 119600},
        },
        createdAt: testDate,
      );

      await tester.pumpWidget(
        wrapWidget(
          ChatMessageBubble(
            message: message,
            selectionMode: false,
            selected: false,
            onTap: () {},
            onLongPress: () {},
            onCopy: () {},
            onExport: () {},
          ),
        ),
      );

      expect(find.text('耗时 2m 0s'), findsOneWidget);
    });

    testWidgets('用户消息不显示 AI token 信息', (tester) async {
      final message = XiaoMiMessage(
        id: 8,
        conversationId: 1,
        role: XiaoMiMessageRole.user,
        content: '用户消息',
        metadata: {
          'aiUsage': {
            'promptTokens': 10,
            'completionTokens': 20,
            'durationMs': 300,
          },
        },
        createdAt: testDate,
      );

      await tester.pumpWidget(
        wrapWidget(
          ChatMessageBubble(
            message: message,
            selectionMode: false,
            selected: false,
            onTap: () {},
            onLongPress: () {},
            onCopy: () {},
            onExport: () {},
          ),
        ),
      );

      expect(find.text('上送 10'), findsNothing);
      expect(find.text('输出 20'), findsNothing);
      expect(find.text('耗时 300ms'), findsNothing);
    });

    testWidgets('非选择模式下用户消息也应展示复制按钮并可触发回调', (tester) async {
      var copied = false;
      final message = XiaoMiMessage(
        id: 2,
        conversationId: 1,
        role: XiaoMiMessageRole.user,
        content: '用户可复制内容',
        metadata: null,
        createdAt: testDate,
      );

      await tester.pumpWidget(
        wrapWidget(
          ChatMessageBubble(
            message: message,
            selectionMode: false,
            selected: false,
            onTap: () {},
            onLongPress: () {},
            onCopy: () => copied = true,
            onExport: () {},
          ),
        ),
      );

      expect(find.text('复制'), findsOneWidget);
      await tester.tap(find.text('复制'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      expect(copied, isTrue);
      expect(find.text('已复制'), findsNothing);
    });

    testWidgets('非选择模式下 AI 消息点击导出应直接触发回调', (tester) async {
      var exported = false;
      final message = XiaoMiMessage(
        id: 4,
        conversationId: 1,
        role: XiaoMiMessageRole.assistant,
        content: '导出测试',
        metadata: null,
        createdAt: testDate,
      );

      await tester.pumpWidget(
        wrapWidget(
          ChatMessageBubble(
            message: message,
            selectionMode: false,
            selected: false,
            onTap: () {},
            onLongPress: () {},
            onCopy: () {},
            onExport: () => exported = true,
          ),
        ),
      );

      expect(find.text('导出'), findsOneWidget);
      await tester.tap(find.text('导出'));
      await tester.pump();
      expect(exported, isTrue);
    });

    testWidgets('复制和导出按钮应使用更清晰的尺寸与字重', (tester) async {
      final message = XiaoMiMessage(
        id: 6,
        conversationId: 1,
        role: XiaoMiMessageRole.assistant,
        content: '样式检查',
        metadata: null,
        createdAt: testDate,
      );

      await tester.pumpWidget(
        wrapWidget(
          ChatMessageBubble(
            message: message,
            selectionMode: false,
            selected: false,
            onTap: () {},
            onLongPress: () {},
            onCopy: () {},
            onExport: () {},
          ),
        ),
      );

      final copyChipRect = tester.getRect(
        find.byKey(const ValueKey('xiao_mi_copy_action_chip')),
      );
      final exportChipRect = tester.getRect(
        find.byKey(const ValueKey('xiao_mi_export_action_chip')),
      );
      expect(copyChipRect.height, greaterThanOrEqualTo(28));
      expect(exportChipRect.height, greaterThanOrEqualTo(28));

      final copyLabel = tester.widget<Text>(find.text('复制'));
      final exportLabel = tester.widget<Text>(find.text('导出'));
      expect(copyLabel.style?.fontSize, greaterThanOrEqualTo(12));
      expect(exportLabel.style?.fontSize, greaterThanOrEqualTo(12));
      expect(copyLabel.style?.fontWeight, FontWeight.w600);
      expect(exportLabel.style?.fontWeight, FontWeight.w600);
    });

    testWidgets('非选择模式下用户消息不应展示导出按钮', (tester) async {
      var exported = false;
      final message = XiaoMiMessage(
        id: 5,
        conversationId: 1,
        role: XiaoMiMessageRole.user,
        content: '用户消息不支持导出',
        metadata: null,
        createdAt: testDate,
      );

      await tester.pumpWidget(
        wrapWidget(
          ChatMessageBubble(
            message: message,
            selectionMode: false,
            selected: false,
            onTap: () {},
            onLongPress: () {},
            onCopy: () {},
            onExport: () => exported = true,
          ),
        ),
      );

      expect(find.text('导出'), findsNothing);
      expect(exported, isFalse);
    });

    testWidgets('选择模式下不应展示复制按钮', (tester) async {
      final message = XiaoMiMessage(
        id: 3,
        conversationId: 1,
        role: XiaoMiMessageRole.assistant,
        content: '选择模式消息',
        metadata: null,
        createdAt: testDate,
      );

      await tester.pumpWidget(
        wrapWidget(
          ChatMessageBubble(
            message: message,
            selectionMode: true,
            selected: false,
            onTap: () {},
            onLongPress: () {},
            onCopy: () {},
            onExport: () {},
          ),
        ),
      );

      expect(find.text('复制'), findsNothing);
      expect(find.text('已复制'), findsNothing);
      expect(find.text('导出'), findsNothing);
    });
  });
}
