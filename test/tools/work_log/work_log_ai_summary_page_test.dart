import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_config.dart';
import 'package:life_tools/core/ai/ai_config_service.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:life_tools/core/tags/models/tag.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/work_log/pages/calendar/work_log_ai_summary_page.dart';
import 'package:life_tools/tools/work_log/pages/work_log_tool_page.dart';
import 'package:life_tools/tools/work_log/services/work_log_service.dart';
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

    testWidgets('筛选项顺序应为时间范围、归属、任务', (tester) async {
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
          minutes: 30,
          content: '处理需求',
          now: DateTime(2026, 1, 3),
        ),
      );

      await tester.pumpWidget(
        TestAppWrapper(child: WorkLogToolPage(repository: repository)),
      );
      await tester.pump(const Duration(milliseconds: 900));
      await _openAiSummaryPage(tester);

      final rangeY = tester
          .getTopLeft(
            find.byKey(const ValueKey('work_log_ai_summary_range_card')),
          )
          .dy;
      final affiliationY = tester
          .getTopLeft(
            find.byKey(const ValueKey('work_log_ai_summary_affiliation_card')),
          )
          .dy;
      final taskY = tester
          .getTopLeft(
            find.byKey(const ValueKey('work_log_ai_summary_task_card')),
          )
          .dy;

      expect(rangeY, lessThan(affiliationY));
      expect(affiliationY, lessThan(taskY));
    });

    testWidgets('选择归属后仅显示满足时间范围与归属的任务', (tester) async {
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);

      final teamATag = Tag(
        id: 11,
        name: '团队A',
        color: null,
        sortIndex: 0,
        createdAt: day,
        updatedAt: day,
      );
      final teamBTag = Tag(
        id: 12,
        name: '团队B',
        color: null,
        sortIndex: 1,
        createdAt: day,
        updatedAt: day,
      );

      final teamATask = WorkTask.create(
        title: '团队A任务',
        description: '',
        startAt: null,
        endAt: null,
        status: WorkTaskStatus.doing,
        estimatedMinutes: 0,
        now: day,
      ).copyWith(id: 1);
      final teamBTask = WorkTask.create(
        title: '团队B任务',
        description: '',
        startAt: null,
        endAt: null,
        status: WorkTaskStatus.doing,
        estimatedMinutes: 0,
        now: day,
      ).copyWith(id: 2);
      final noTagTask = WorkTask.create(
        title: '无归属任务',
        description: '',
        startAt: null,
        endAt: null,
        status: WorkTaskStatus.doing,
        estimatedMinutes: 0,
        now: day,
      ).copyWith(id: 3);

      final service = _FakeSummaryWorkLogService(
        tasks: [teamATask, teamBTask, noTagTask],
        affiliations: [teamATag, teamBTag],
        entries: [
          WorkTimeEntry.create(
            taskId: 1,
            workDate: day,
            minutes: 60,
            content: '推进团队A需求',
            now: day,
          ),
          WorkTimeEntry.create(
            taskId: 2,
            workDate: day,
            minutes: 50,
            content: '推进团队B需求',
            now: day,
          ),
          WorkTimeEntry.create(
            taskId: 3,
            workDate: day,
            minutes: 40,
            content: '处理公共事务',
            now: day,
          ),
        ],
        tagIdsByTaskId: {
          1: [11],
          2: [12],
          3: const [],
        },
      );

      await tester.pumpWidget(
        TestAppWrapper(
          child: ChangeNotifierProvider<WorkLogService>.value(
            value: service,
            child: const WorkLogAiSummaryPage(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      final teamATaskChip = find.byKey(
        const ValueKey('work_log_ai_summary_task_1'),
      );
      final teamBTaskChip = find.byKey(
        const ValueKey('work_log_ai_summary_task_2'),
      );
      final noTagTaskChip = find.byKey(
        const ValueKey('work_log_ai_summary_task_3'),
      );

      expect(teamATaskChip, findsOneWidget);
      expect(teamBTaskChip, findsOneWidget);
      expect(noTagTaskChip, findsOneWidget);

      final teamAAffiliationChip = find.byKey(
        const ValueKey('work_log_ai_summary_affiliation_11'),
      );
      await tester.tap(teamAAffiliationChip, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      expect(teamATaskChip, findsOneWidget);
      expect(teamBTaskChip, findsNothing);
      expect(noTagTaskChip, findsNothing);
    });

    testWidgets('点击生成总结后应显示遮罩与等待时长并展示结果', (tester) async {
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

      final fakeClient = FakeOpenAiClient(
        replyText: '这是 AI 总结结果',
        responseDelay: const Duration(seconds: 2),
      );
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
      await _openAiSummaryPage(tester);

      final taskChip = find.byKey(ValueKey('work_log_ai_summary_task_$taskId'));
      await tester.tap(taskChip);
      await tester.pump(const Duration(milliseconds: 200));

      final generateButton = find.byKey(
        const ValueKey('work_log_ai_summary_generate_button'),
      );
      await tester.ensureVisible(generateButton);
      await tester.tap(generateButton);
      await tester.pump();

      expect(
        find.byKey(const ValueKey('work_log_ai_summary_generating_overlay')),
        findsOneWidget,
      );
      expect(find.text('正在生成总结，请耐心等待…'), findsOneWidget);
      expect(find.text('已等待 0 秒'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('已等待 1 秒'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('work_log_ai_summary_generating_overlay')),
        findsNothing,
      );
      expect(find.text('这是 AI 总结结果'), findsOneWidget);
      expect(fakeClient.lastRequest, isNotNull);
      expect(fakeClient.lastRequest!.messages.last.content, contains('任务A'));
    });
  });
}

Future<void> _openAiSummaryPage(WidgetTester tester) async {
  await tester.tap(find.text('日历'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));

  await tester.tap(find.byKey(const ValueKey('work_log_ai_summary_button')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

class _FakeSummaryWorkLogService extends WorkLogService {
  _FakeSummaryWorkLogService({
    required List<WorkTask> tasks,
    required List<Tag> affiliations,
    required List<WorkTimeEntry> entries,
    required Map<int, List<int>> tagIdsByTaskId,
  }) : _tasks = tasks,
       _affiliations = affiliations,
       _entries = entries,
       _tagIdsByTaskId = tagIdsByTaskId,
       super(repository: FakeWorkLogRepository());

  final List<WorkTask> _tasks;
  final List<Tag> _affiliations;
  final List<WorkTimeEntry> _entries;
  final Map<int, List<int>> _tagIdsByTaskId;

  @override
  List<WorkTask> get allTasks => List.unmodifiable(_tasks);

  @override
  List<Tag> get availableTags => List.unmodifiable(_affiliations);

  @override
  Future<List<WorkTimeEntry>> listTimeEntriesInRange(
    DateTime startInclusive,
    DateTime endExclusive,
  ) async {
    final start = DateTime(
      startInclusive.year,
      startInclusive.month,
      startInclusive.day,
    );
    final end = DateTime(
      endExclusive.year,
      endExclusive.month,
      endExclusive.day,
    );
    return _entries
        .where(
          (entry) =>
              !entry.workDate.isBefore(start) && entry.workDate.isBefore(end),
        )
        .toList();
  }

  @override
  Future<List<int>> listTagIdsForTask(int taskId) async {
    return List<int>.from(_tagIdsByTaskId[taskId] ?? const <int>[]);
  }
}
