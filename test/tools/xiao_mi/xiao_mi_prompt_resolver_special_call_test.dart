import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_prompt_resolver.dart';

import '../../test_helpers/fake_work_log_repository.dart';

void main() {
  group('XiaoMiPromptResolver special_call', () {
    late FakeWorkLogRepository repository;

    setUp(() {
      repository = FakeWorkLogRepository();
    });

    test('quickPrompts 应包含周/月/季度/年度总结入口', () {
      final resolver = XiaoMiPromptResolver(workLogRepository: repository);
      final ids = resolver.quickPrompts
          .map((e) => e.id)
          .toList(growable: false);
      expect(
        ids,
        containsAll(<String>[
          'work_log_week_summary',
          'work_log_month_summary',
          'work_log_quarter_summary',
          'work_log_year_summary',
        ]),
      );
    });

    test('resolveQuickPromptText 应命中内置预置词并标记 preset 来源', () async {
      final now = DateTime(2026, 5, 20, 9);
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务预置',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: now,
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 5, 19),
          minutes: 30,
          content: '预置周总结数据',
          now: now,
        ),
      );

      final resolver = XiaoMiPromptResolver(
        workLogRepository: repository,
        nowProvider: () => now,
      );

      final resolved = await resolver.resolveQuickPromptText(' 本周工作总结 ');

      expect(resolved, isNotNull);
      expect((resolved!.metadata ?? const {})['triggerSource'], 'preset');
      expect((resolved.metadata ?? const {})['queryStartDate'], '2026-05-18');
      expect((resolved.metadata ?? const {})['queryEndDate'], '2026-05-24');
      expect(resolved.aiPrompt, contains('内容：预置周总结数据'));
    });

    test('work_log_month_summary 应生成本月范围总结并写入日期范围', () async {
      final now = DateTime(2026, 5, 20, 9);
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: now,
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 5, 10),
          minutes: 30,
          content: '月内记录',
          now: now,
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 4, 30),
          minutes: 45,
          content: '月外记录',
          now: now,
        ),
      );

      final resolver = XiaoMiPromptResolver(
        workLogRepository: repository,
        nowProvider: () => now,
      );

      final resolved = await resolver.resolveSpecialCall(
        callId: 'work_log_month_summary',
        displayText: '本月工作总结',
      );

      final metadata = resolved.metadata ?? const {};
      expect(metadata['queryStartDate'], '2026-05-01');
      expect(metadata['queryEndDate'], '2026-05-31');
      expect(resolved.aiPrompt, contains('时间范围：2026-05-01 至 2026-05-31（含）'));
      expect(resolved.aiPrompt, contains('内容：月内记录'));
      expect(resolved.aiPrompt, isNot(contains('内容：月外记录')));
    });

    test('work_log_month_summary 指定 year/month 时应按指定月份统计', () async {
      final now = DateTime(2026, 3, 20, 9);
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务D',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: now,
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 1, 15),
          minutes: 40,
          content: '一月记录',
          now: now,
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 3, 10),
          minutes: 30,
          content: '三月记录',
          now: now,
        ),
      );

      final resolver = XiaoMiPromptResolver(
        workLogRepository: repository,
        nowProvider: () => now,
      );

      final resolved = await resolver.resolveSpecialCall(
        callId: 'work_log_month_summary',
        displayText: '今年一月份工作总结',
        arguments: const <String, Object?>{'year': 2026, 'month': 1},
      );

      final metadata = resolved.metadata ?? const {};
      expect(metadata['queryStartDate'], '2026-01-01');
      expect(metadata['queryEndDate'], '2026-01-31');
      expect(resolved.aiPrompt, contains('时间范围：2026-01-01 至 2026-01-31（含）'));
      expect(resolved.aiPrompt, contains('内容：一月记录'));
      expect(resolved.aiPrompt, isNot(contains('内容：三月记录')));
    });

    test('work_log_week_summary 应按周一到周日统计', () async {
      final now = DateTime(2026, 5, 20, 9); // 周三
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务B',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: now,
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 5, 18), // 周一
          minutes: 60,
          content: '本周记录',
          now: now,
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 5, 17), // 上周日
          minutes: 20,
          content: '上周记录',
          now: now,
        ),
      );

      final resolver = XiaoMiPromptResolver(
        workLogRepository: repository,
        nowProvider: () => now,
      );

      final resolved = await resolver.resolveSpecialCall(
        callId: 'work_log_week_summary',
        displayText: '本周工作总结',
      );

      final metadata = resolved.metadata ?? const {};
      expect(metadata['queryStartDate'], '2026-05-18');
      expect(metadata['queryEndDate'], '2026-05-24');
      expect(resolved.aiPrompt, contains('时间范围：2026-05-18 至 2026-05-24（含）'));
      expect(resolved.aiPrompt, contains('内容：本周记录'));
      expect(resolved.aiPrompt, isNot(contains('内容：上周记录')));
    });

    test('work_log_quarter_summary 应按当前季度统计', () async {
      final now = DateTime(2026, 5, 20, 9); // Q2
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务C',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: now,
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 4, 1),
          minutes: 50,
          content: '季度内记录',
          now: now,
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 3, 31),
          minutes: 50,
          content: '季度外记录',
          now: now,
        ),
      );

      final resolver = XiaoMiPromptResolver(
        workLogRepository: repository,
        nowProvider: () => now,
      );

      final resolved = await resolver.resolveSpecialCall(
        callId: 'work_log_quarter_summary',
        displayText: '本季度工作总结',
      );

      final metadata = resolved.metadata ?? const {};
      expect(metadata['queryStartDate'], '2026-04-01');
      expect(metadata['queryEndDate'], '2026-06-30');
      expect(resolved.aiPrompt, contains('时间范围：2026-04-01 至 2026-06-30（含）'));
      expect(resolved.aiPrompt, contains('内容：季度内记录'));
      expect(resolved.aiPrompt, isNot(contains('内容：季度外记录')));
    });

    test('work_log_range_summary 应支持 YYYYMMDD 日期区间', () async {
      final now = DateTime(2026, 8, 20, 9);
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务E',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: now,
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 1, 15),
          minutes: 35,
          content: '年度内记录',
          now: now,
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2025, 12, 31),
          minutes: 20,
          content: '年度外记录',
          now: now,
        ),
      );

      final resolver = XiaoMiPromptResolver(
        workLogRepository: repository,
        nowProvider: () => now,
      );

      final resolved = await resolver.resolveSpecialCall(
        callId: 'work_log_range_summary',
        displayText: '今年工作总结',
        arguments: const <String, Object?>{
          'start_date': '20260101',
          'end_date': '20261231',
        },
      );

      final metadata = resolved.metadata ?? const {};
      expect(metadata['queryStartDate'], '2026-01-01');
      expect(metadata['queryEndDate'], '2026-12-31');
      expect(resolved.aiPrompt, contains('时间范围：2026-01-01 至 2026-12-31（含）'));
      expect(resolved.aiPrompt, contains('内容：年度内记录'));
      expect(resolved.aiPrompt, isNot(contains('内容：年度外记录')));
    });

    test('今年工作总结应优先按当前年统计，忽略错误 year 参数', () async {
      final now = DateTime(2026, 8, 20, 9);
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务F',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: now,
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 6, 1),
          minutes: 25,
          content: '今年记录',
          now: now,
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2025, 6, 1),
          minutes: 30,
          content: '去年记录',
          now: now,
        ),
      );

      final resolver = XiaoMiPromptResolver(
        workLogRepository: repository,
        nowProvider: () => now,
      );

      final resolved = await resolver.resolveSpecialCall(
        callId: 'work_log_year_summary',
        displayText: '今年工作总结',
        arguments: const <String, Object?>{'year': 2025},
      );

      final metadata = resolved.metadata ?? const {};
      expect(metadata['queryStartDate'], '2026-01-01');
      expect(metadata['queryEndDate'], '2026-12-31');
      expect(resolved.aiPrompt, contains('时间范围：2026-01-01 至 2026-12-31（含）'));
      expect(resolved.aiPrompt, contains('内容：今年记录'));
      expect(resolved.aiPrompt, isNot(contains('内容：去年记录')));
    });
  });
}
