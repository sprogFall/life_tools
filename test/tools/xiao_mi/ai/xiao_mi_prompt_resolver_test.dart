import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_prompt_resolver.dart';

import '../../../test_helpers/fake_work_log_repository.dart';

void main() {
  test('resolveSpecialCall 应支持 work_log_query', () async {
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

    expect((resolved.metadata ?? const {})['triggerTool'], 'work_log');
    expect((resolved.metadata ?? const {})['queryType'], 'filtered_query');
    expect(resolved.aiPrompt, contains('工作记录查询结果'));
    expect(
      resolved.aiPrompt,
      contains('work_date=2026-04-12 | task_title=接口联调 | minutes=90'),
    );
  });
}
