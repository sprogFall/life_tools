import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_work_log_prompt_builder.dart';

import '../../../test_helpers/fake_work_log_repository.dart';

void main() {
  group('XiaoMiWorkLogSummaryPromptBuilder 多关键词匹配', () {
    test('应支持子关键词匹配：海曙应急局 -> 应急局', () async {
      final repository = FakeWorkLogRepository();
      final now = DateTime(2026, 4, 20, 9);
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '海曙应急管理局驻点',
          description: '应急系统维护',
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
          workDate: DateTime(2026, 4, 12),
          minutes: 120,
          content: '应急管理局现场支持',
          now: now,
        ),
      );

      final builder = XiaoMiWorkLogSummaryPromptBuilder(
        repository: repository,
        nowProvider: () => now,
      );

      final prompt = await builder.buildQuery(
        displayText: '查询海曙应急局工作记录',
        start: DateTime(2026, 4, 1),
        endInclusive: DateTime(2026, 4, 30),
        keyword: '海曙应急局',
        fields: const <String>['work_date', 'task_title', 'minutes'],
      );

      expect(prompt, contains('工作记录查询结果'));
      expect(prompt, contains('关键词：海曙应急局'));
      expect(prompt, contains('命中记录数：1'));
      expect(
        prompt,
        contains('work_date=2026-04-12 | task_title=海曙应急管理局驻点 | minutes=120'),
      );
    });

    test('应支持子关键词匹配：海曙应急局 -> 海曙', () async {
      final repository = FakeWorkLogRepository();
      final now = DateTime(2026, 4, 20, 9);
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '海曙区项目',
          description: '海曙区政务系统',
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
          workDate: DateTime(2026, 4, 15),
          minutes: 90,
          content: '海曙区现场调研',
          now: now,
        ),
      );

      final builder = XiaoMiWorkLogSummaryPromptBuilder(
        repository: repository,
        nowProvider: () => now,
      );

      final prompt = await builder.buildQuery(
        displayText: '查询海曙应急局工作记录',
        start: DateTime(2026, 4, 1),
        endInclusive: DateTime(2026, 4, 30),
        keyword: '海曙应急局',
        fields: const <String>['work_date', 'task_title', 'minutes'],
      );

      expect(prompt, contains('工作记录查询结果'));
      expect(prompt, contains('命中记录数：1'));
      expect(
        prompt,
        contains('work_date=2026-04-15 | task_title=海曙区项目 | minutes=90'),
      );
    });

    test('应支持子关键词匹配：海曙应急局 -> 应急', () async {
      final repository = FakeWorkLogRepository();
      final now = DateTime(2026, 4, 20, 9);
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '应急响应系统',
          description: '应急预案编制',
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
          workDate: DateTime(2026, 4, 18),
          minutes: 60,
          content: '应急系统测试',
          now: now,
        ),
      );

      final builder = XiaoMiWorkLogSummaryPromptBuilder(
        repository: repository,
        nowProvider: () => now,
      );

      final prompt = await builder.buildQuery(
        displayText: '查询海曙应急局工作记录',
        start: DateTime(2026, 4, 1),
        endInclusive: DateTime(2026, 4, 30),
        keyword: '海曙应急局',
        fields: const <String>['work_date', 'task_title', 'minutes'],
      );

      expect(prompt, contains('工作记录查询结果'));
      expect(prompt, contains('命中记录数：1'));
      expect(
        prompt,
        contains('work_date=2026-04-18 | task_title=应急响应系统 | minutes=60'),
      );
    });

    test('不匹配时应返回空结果', () async {
      final repository = FakeWorkLogRepository();
      final now = DateTime(2026, 4, 20, 9);
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '其他项目',
          description: '无关任务',
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
          workDate: DateTime(2026, 4, 10),
          minutes: 30,
          content: '其他工作',
          now: now,
        ),
      );

      final builder = XiaoMiWorkLogSummaryPromptBuilder(
        repository: repository,
        nowProvider: () => now,
      );

      final prompt = await builder.buildQuery(
        displayText: '查询海曙应急局工作记录',
        start: DateTime(2026, 4, 1),
        endInclusive: DateTime(2026, 4, 30),
        keyword: '海曙应急局',
        fields: const <String>['work_date', 'task_title', 'minutes'],
      );

      expect(prompt, contains('工作记录查询结果'));
      expect(prompt, contains('命中记录数：0'));
      expect(prompt, contains('- (无)'));
    });
  });
}
