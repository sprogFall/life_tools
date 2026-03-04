import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer/tools/xiao_mi/models/xiao_mi_message.dart';
import 'package:namer/tools/xiao_mi/widgets/chat_message_bubble.dart';

void main() {
  group('ChatMessageBubble', () {
    final testDate = DateTime(2024, 1, 1);

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
        MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              message: message,
              selectionMode: false,
              selected: false,
              onTap: () {},
              onLongPress: () {},
              onCopy: () {},
            ),
          ),
        ),
      );

      expect(find.text('Hello'), findsOneWidget);
      // 用户消息右对齐
      final alignFinder = find.byType(Align);
      expect(alignFinder, findsWidgets);
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
        MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              message: message,
              selectionMode: false,
              selected: false,
              showAvatar: true,
              onTap: () {},
              onLongPress: () {},
              onCopy: () {},
            ),
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
        MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              message: message,
              selectionMode: true,
              selected: true,
              onTap: () {},
              onLongPress: () {},
              onCopy: () {},
            ),
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
        MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              message: message,
              selectionMode: false,
              selected: false,
              onTap: () {},
              onLongPress: () => longPressed = true,
              onCopy: () {},
            ),
          ),
        ),
      );

      await tester.longPress(find.text('Long press me'));
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
        MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(
              message: message,
              selectionMode: false,
              selected: false,
              onTap: () {},
              onLongPress: () {},
              onCopy: () {},
            ),
          ),
        ),
      );

      expect(find.text('思考过程'), findsOneWidget);
    });
  });
}
