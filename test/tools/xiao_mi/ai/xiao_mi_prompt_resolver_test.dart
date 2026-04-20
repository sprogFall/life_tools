import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_prompt_resolver.dart';

import '../../../test_helpers/fake_work_log_repository.dart';

void main() {
  test('resolveSpecialCall 应支持 work_time_query', () async {
    final repository = FakeWorkLogRepository();
    final now = DateTime(2026, 4, 20, 9);
    final taskId = await repository.createTask(
      WorkTask.create(
        title: '接口联调',
        description: '支付回调',
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
        minutes: 90,
        content: '完成支付接口联调',
        now: now,
      ),
    );

    final resolver = XiaoMiPromptResolver(
      workLogRepository: repository,
      nowProvider: () => now,
    );

    final resolved = await resolver.resolveSpecialCall(
      callId: 'work_time_query',
      displayText: '查询接口记录',
      arguments: const <String, Object?>{
        'start_date': '20260401',
        'end_date': '20260430',
        'keyword': '接口',
        'status': 'doing',
        'fields': <String>['work_date', 'task_title', 'minutes'],
      },
    );

    expect((resolved.metadata ?? const {})['triggerTool'], 'work_log');
    expect((resolved.metadata ?? const {})['queryType'], 'time_query');
    expect(resolved.aiPrompt, contains('工作记录查询结果'));
    expect(
      resolved.aiPrompt,
      contains('work_date=2026-04-12 | task_title=接口联调 | minutes=90'),
    );
  });

  test('resolveSpecialCall 应支持 work_task_query', () async {
    final repository = FakeWorkLogRepository();
    final now = DateTime(2026, 4, 20, 9);
    await repository.createTask(
      WorkTask.create(
        title: '防汛巡查',
        description: '堤坝巡查任务',
        startAt: null,
        endAt: null,
        status: WorkTaskStatus.doing,
        estimatedMinutes: 180,
        now: now,
      ),
    );

    final resolver = XiaoMiPromptResolver(
      workLogRepository: repository,
      nowProvider: () => now,
    );

    final resolved = await resolver.resolveSpecialCall(
      callId: 'work_task_query',
      displayText: '查询标题包含防汛的任务',
      arguments: const <String, Object?>{
        'keyword': '防汛',
        'status': 'doing',
        'fields': <String>['task_title', 'task_status', 'estimated_minutes'],
      },
    );

    expect((resolved.metadata ?? const {})['triggerTool'], 'work_log');
    expect((resolved.metadata ?? const {})['queryType'], 'task_query');
    expect(resolved.aiPrompt, contains('任务查询结果'));
    expect(
      resolved.aiPrompt,
      contains('task_title=防汛巡查 | task_status=doing | estimated_minutes=180'),
    );
  });

  test('resolveSpecialCall 应兼容 work_log_query 作为工时查询别名', () async {
    final repository = FakeWorkLogRepository();
    final now = DateTime(2026, 4, 20, 9);
    final taskId = await repository.createTask(
      WorkTask.create(
        title: '接口联调',
        description: '支付回调',
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
        minutes: 90,
        content: '完成支付接口联调',
        now: now,
      ),
    );

    final resolver = XiaoMiPromptResolver(
      workLogRepository: repository,
      nowProvider: () => now,
    );

    final resolved = await resolver.resolveSpecialCall(
      callId: 'work_log_query',
      displayText: '查询接口记录',
      arguments: const <String, Object?>{
        'start_date': '20260401',
        'end_date': '20260430',
        'keyword': '接口',
        'status': 'doing',
        'fields': <String>['work_date', 'task_title', 'minutes'],
      },
    );

    expect((resolved.metadata ?? const {})['queryType'], 'time_query');
    expect(resolved.aiPrompt, contains('工作记录查询结果'));
  });
}
