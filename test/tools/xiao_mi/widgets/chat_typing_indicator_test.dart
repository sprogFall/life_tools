import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:namer/tools/xiao_mi/widgets/chat_typing_indicator.dart';

void main() {
  group('ChatTypingIndicator', () {
    testWidgets('显示打字指示器组件', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatTypingIndicator(),
          ),
        ),
      );

      // 验证组件存在
      expect(find.byType(ChatTypingIndicator), findsOneWidget);

      // 初始动画状态
      await tester.pump();
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('左对齐显示', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatTypingIndicator(),
          ),
        ),
      );

      final alignFinder = find.byType(Align);
      expect(alignFinder, findsOneWidget);

      final align = tester.widget<Align>(alignFinder);
      expect(align.alignment, Alignment.centerLeft);
    });
  });
}
