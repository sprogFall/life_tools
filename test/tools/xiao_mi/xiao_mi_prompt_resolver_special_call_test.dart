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

    test('work_log_month_summary 应生成本月范围总结并写入 presetId', () async {
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

      expect(
        (resolved.metadata ?? const {})['presetId'],
        'work_log_month_summary',
      );
      expect(resolved.aiPrompt, contains('时间范围：2026-05-01 至 2026-05-31（含）'));
      expect(resolved.aiPrompt, contains('内容：月内记录'));
      expect(resolved.aiPrompt, isNot(contains('内容：月外记录')));
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

      expect(
        (resolved.metadata ?? const {})['presetId'],
        'work_log_week_summary',
      );
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

      expect(
        (resolved.metadata ?? const {})['presetId'],
        'work_log_quarter_summary',
      );
      expect(resolved.aiPrompt, contains('时间范围：2026-04-01 至 2026-06-30（含）'));
      expect(resolved.aiPrompt, contains('内容：季度内记录'));
      expect(resolved.aiPrompt, isNot(contains('内容：季度外记录')));
    });
  });
}
