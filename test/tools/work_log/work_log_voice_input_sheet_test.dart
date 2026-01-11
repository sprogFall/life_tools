import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/pages/task/work_log_voice_input_sheet.dart';

void main() {
  group('WorkLogVoiceInputSheet', () {
    testWidgets('应该显示AI录入界面并支持文本输入', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    WorkLogVoiceInputSheet.show(context);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle(const Duration(milliseconds: 800));

      // 验证标题为"AI录入"
      expect(find.text('AI录入'), findsOneWidget);

      // 验证输入框存在
      expect(find.byKey(const ValueKey('work_log_ai_text_field')), findsOneWidget);

      // 验证提交按钮存在
      expect(find.text('提交给AI'), findsOneWidget);
    });

    testWidgets('应该能够输入文本并返回', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await WorkLogVoiceInputSheet.show(context);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle(const Duration(milliseconds: 800));

      // 输入文本
      await tester.enterText(
        find.byKey(const ValueKey('work_log_ai_text_field')),
        '今天完成了登录功能',
      );
      await tester.pump();

      // 点击提交
      await tester.tap(find.text('提交给AI'));
      await tester.pumpAndSettle();

      expect(result, '今天完成了登录功能');
    });

    testWidgets('点击取消应该返回null', (tester) async {
      String? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await WorkLogVoiceInputSheet.show(context);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle(const Duration(milliseconds: 800));

      // 点击取消按钮（通过图标查找）
      await tester.tap(find.byIcon(CupertinoIcons.xmark));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });
}
