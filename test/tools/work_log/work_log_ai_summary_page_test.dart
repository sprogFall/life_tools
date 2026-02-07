import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/work_log/pages/work_log_tool_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/fake_openai_client.dart';
import '../../test_helpers/fake_work_log_repository.dart';
import '../../test_helpers/test_app_wrapper.dart';

void main() {
  group('WorkLog AI总结页', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('日历页右下角应展示 AI 总结按钮并可进入总结页', (tester) async {
      await tester.pumpWidget(
        TestAppWrapper(
          child: WorkLogToolPage(repository: FakeWorkLogRepository()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.text('日历'));
      await tester.pumpAndSettle();

      final summaryButton = find.byKey(
        const ValueKey('work_log_ai_summary_button'),
      );
      expect(summaryButton, findsOneWidget);

      await tester.tap(summaryButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(
        find.byKey(const ValueKey('work_log_ai_summary_page')),
        findsOneWidget,
      );
      expect(find.text('AI总结'), findsOneWidget);
    });

    testWidgets('时间范围内无工时的任务应置灰且不可点选', (tester) async {
      final repository = FakeWorkLogRepository();
      final activeTaskId = await repository.createTask(
        WorkTask.create(
          title: '有工时任务',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );
      final idleTaskId = await repository.createTask(
        WorkTask.create(
          title: '无工时任务',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 2),
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: activeTaskId,
          workDate: DateTime.now(),
          minutes: 60,
          content: '处理需求',
          now: DateTime(2026, 1, 3),
        ),
      );

      await tester.pumpWidget(
        TestAppWrapper(child: WorkLogToolPage(repository: repository)),
      );
      await tester.pump(const Duration(milliseconds: 800));

      await tester.tap(find.text('日历'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('work_log_ai_summary_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      final activeChip = tester.widget<CupertinoButton>(
        find.byKey(ValueKey('work_log_ai_summary_task_$activeTaskId')),
      );
      final idleChip = tester.widget<CupertinoButton>(
        find.byKey(ValueKey('work_log_ai_summary_task_$idleTaskId')),
      );

      expect(activeChip.onPressed, isNotNull);
      expect(idleChip.onPressed, isNull);
    });

    testWidgets('点击生成总结后应展示 AI 返回文本', (tester) async {
      final repository = FakeWorkLogRepository();
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime.now(),
          minutes: 120,
          content: '完成模块开发与联调',
          now: DateTime(2026, 1, 1),
        ),
      );

      final configService = AiConfigService();
      await configService.init();
      await configService.save(
        const AiConfig(
          baseUrl: 'https://api.example.com',
          apiKey: 'test-key',
          model: 'gpt-4o-mini',
          temperature: 0.5,
          maxOutputTokens: 1500,
        ),
      );

      final fakeClient = FakeOpenAiClient(replyText: '这是 AI 总结结果');
      final aiService = AiService(
        configService: configService,
        client: fakeClient,
      );

      await tester.pumpWidget(
        Provider<AiService>.value(
          value: aiService,
          child: TestAppWrapper(child: WorkLogToolPage(repository: repository)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 900));

      await tester.tap(find.text('日历'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('work_log_ai_summary_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));

      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('work_log_ai_summary_generate_button')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle(const Duration(milliseconds: 1200));

      expect(fakeClient.lastRequest, isNotNull);
      expect(fakeClient.lastRequest!.messages.length, greaterThanOrEqualTo(2));
      expect(fakeClient.lastRequest!.messages.last.content, contains('任务A'));
    });
  });
}
