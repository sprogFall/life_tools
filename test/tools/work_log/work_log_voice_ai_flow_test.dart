import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/ai/work_log_ai_assistant.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/pages/work_log_tool_page.dart';

import '../../test_helpers/fake_work_log_repository.dart';

void main() {
  group('WorkLog 语音 -> AI -> 预填表单', () {
    testWidgets('create_task 应打开创建任务页并预填标题', (tester) async {
      final repository = FakeWorkLogRepository();
      final aiAssistant = _FakeAiAssistant(
        response: '''
{"type":"create_task","task":{"title":"实现语音输入","description":"在任务页底部加语音按钮","status":"doing","estimated_minutes":120}}
''',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WorkLogToolPage(
            repository: repository,
            aiAssistant: aiAssistant,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.byKey(const ValueKey('work_log_voice_input_button')));
      await tester.pumpAndSettle(const Duration(milliseconds: 800));

      await tester.enterText(
        find.byKey(const ValueKey('work_log_voice_text_field')),
        '我要创建一个任务：实现语音输入',
      );
      await tester.tap(find.widgetWithText(CupertinoButton, '确认'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('创建任务'), findsOneWidget);

      final titleField = tester.widget<CupertinoTextField>(
        find.byKey(const ValueKey('task_title_field')),
      );
      expect(titleField.controller?.text, '实现语音输入');
    });

    testWidgets('add_time_entry 应打开记录工时页并预填字段', (tester) async {
      final repository = FakeWorkLogRepository();
      await repository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );

      final aiAssistant = _FakeAiAssistant(
        response: '''
{"type":"add_time_entry","task_ref":{"title":"任务A"},"time_entry":{"work_date":"2026-01-02","minutes":90,"content":"开发功能A"}}
''',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WorkLogToolPage(
            repository: repository,
            aiAssistant: aiAssistant,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byKey(const ValueKey('work_log_voice_input_button')));
      await tester.pumpAndSettle(const Duration(milliseconds: 800));

      await tester.enterText(
        find.byKey(const ValueKey('work_log_voice_text_field')),
        '在任务A下面记录 90 分钟：开发功能A',
      );
      await tester.tap(find.widgetWithText(CupertinoButton, '确认'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('记录工时'), findsOneWidget);
      expect(find.text('2026-01-02'), findsOneWidget);

      final minutesField = tester.widget<CupertinoTextField>(
        find.byKey(const ValueKey('time_entry_minutes_field')),
      );
      final contentField = tester.widget<CupertinoTextField>(
        find.byKey(const ValueKey('time_entry_content_field')),
      );

      expect(minutesField.controller?.text, '90');
      expect(contentField.controller?.text, '开发功能A');
    });
  });
}

class _FakeAiAssistant implements WorkLogAiAssistant {
  final String response;

  const _FakeAiAssistant({required this.response});

  @override
  Future<String> voiceTextToIntentJson({
    required String voiceText,
    required String context,
  }) async {
    return response;
  }
}
