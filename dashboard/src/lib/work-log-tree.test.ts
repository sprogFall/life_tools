import { describe, expect, it } from 'vitest';

import { buildWorkLogTree, reassignTimeEntryTask } from '@/lib/work-log-tree';

describe('work-log-tree', () => {
  it('按任务聚合工时，并保留未归属节点作为兜底', () => {
    const tasks = [
      { id: 1, title: '整理周报', sort_index: 2, is_pinned: false },
      { id: 2, title: '需求拆分', sort_index: 1, is_pinned: true },
    ];
    const timeEntries = [
      { id: 10, task_id: 1, minutes: 60, content: '周报补充' },
      { id: 11, task_id: 99, minutes: 30, content: '误归类记录' },
    ];

    const groups = buildWorkLogTree(tasks, timeEntries);

    expect(groups.map((group) => group.title)).toEqual(['需求拆分', '整理周报', '未归属 / 异常归属']);
    expect(groups[0]?.entryCount).toBe(0);
    expect(groups[1]?.totalMinutes).toBe(60);
    expect(groups[2]?.entryCount).toBe(1);
    expect(groups[2]?.entries[0]?.content).toBe('误归类记录');
  });

  it('支持把工时记录改挂到新的任务，并刷新更新时间', () => {
    const before = [
      { id: 1, task_id: 1, minutes: 60, content: '完成文案整理', updated_at: 1000 },
      { id: 2, task_id: 1, minutes: 30, content: '补录会议纪要', updated_at: 2000 },
    ];

    const after = reassignTimeEntryTask(before, 2, 3, 987654321);

    expect(after[0]).toEqual(before[0]);
    expect(after[1]).toMatchObject({ id: 2, task_id: 3, updated_at: 987654321 });
  });
});
