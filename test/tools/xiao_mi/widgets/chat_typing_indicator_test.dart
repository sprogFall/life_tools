import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/xiao_mi/widgets/chat_typing_indicator.dart';

void main() {
  group('ChatTypingIndicator', () {
    testWidgets('显示打字指示器组件', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BackdropGroup(child: ChatTypingIndicator())),
        ),
      );

      // 等待 staggered Future.delayed 全部触发（3 dots × 150ms）
      await tester.pump(const Duration(milliseconds: 500));

      // 验证组件存在
      expect(find.byType(ChatTypingIndicator), findsOneWidget);
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('左对齐显示', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BackdropGroup(child: ChatTypingIndicator())),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      final alignFinder = find.byType(Align);
      expect(alignFinder, findsOneWidget);

      final align = tester.widget<Align>(alignFinder);
      expect(align.alignment, Alignment.centerLeft);
    });
  });
}
