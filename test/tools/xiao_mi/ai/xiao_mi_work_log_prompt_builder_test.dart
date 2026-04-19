import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_work_log_prompt_builder.dart';

import '../../../test_helpers/fake_work_log_repository.dart';

void main() {
  test('buildQuery 应支持关键词筛选与字段裁剪', () async {
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

    final builder = XiaoMiWorkLogSummaryPromptBuilder(
      repository: repository,
      nowProvider: () => now,
    );

    final prompt = await builder.buildQuery(
      displayText: '查询接口记录',
      start: DateTime(2026, 4, 1),
      endInclusive: DateTime(2026, 4, 30),
      keyword: '接口',
      statusIds: const <String>['doing'],
      fields: const <String>['work_date', 'task_title', 'minutes'],
    );

    expect(prompt, contains('工作记录查询结果'));
    expect(
      prompt,
      contains('work_date=2026-04-12 | task_title=接口联调 | minutes=90'),
    );
    expect(prompt, isNot(contains('content=')));
  });
}
