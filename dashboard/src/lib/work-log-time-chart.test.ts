import { describe, expect, it } from 'vitest';

import { buildWorkLogTimeChartDataset } from '@/lib/work-log-time-chart';

const tasks = [
  { id: 1, title: '整理周报', sort_index: 1 },
  { id: 2, title: '需求拆分', sort_index: 2 },
  { id: 3, title: '回归测试', sort_index: 3 },
];

const taskTags = [
  { task_id: 1, tag_id: 10 },
  { task_id: 2, tag_id: 11 },
  { task_id: 3, tag_id: 10 },
];

const tagNames = {
  10: '项目A',
  11: '项目B',
};

const jan5Noon = new Date(2026, 0, 5, 12).getTime();
const jan5Afternoon = new Date(2026, 0, 5, 15).getTime();
const jan5Evening = new Date(2026, 0, 5, 18).getTime();
const jan6Noon = new Date(2026, 0, 6, 12).getTime();
const jan6Afternoon = new Date(2026, 0, 6, 16).getTime();

const items = [
  { id: 1, task_id: 1, minutes: 60, work_date: jan5Noon, content: '同步周报' },
  { id: 2, task_id: 2, minutes: 90, work_date: jan5Afternoon, content: '拆分需求' },
  { id: 3, task_id: 1, minutes: 30, work_date: jan5Evening, content: '补充风险' },
  { id: 4, task_id: 3, minutes: 45, work_date: jan6Noon, content: '执行回归' },
  { id: 5, task_id: 999, minutes: 20, work_date: jan6Afternoon, content: '未归属记录' },
];

describe('buildWorkLogTimeChartDataset', () => {
  it('按天按任务聚合工时，并为异常归属补出兜底图例', () => {
    const dataset = buildWorkLogTimeChartDataset({
      tasks,
      items,
      taskTags,
      tagNames,
      filters: {
        startDate: '',
        endDate: '',
        selectedTaskIds: [],
        selectedTagIds: [],
      },
    });

    expect(dataset.availableRange).toEqual({
      startDate: '2026-01-05',
      endDate: '2026-01-06',
    });
    expect(dataset.totalMinutes).toBe(245);
    expect(dataset.maxMinutes).toBe(90);
    expect(dataset.days).toHaveLength(2);
    expect(dataset.days[0]).toMatchObject({
      dateKey: '2026-01-05',
      totalMinutes: 180,
    });
    expect(dataset.days[0].bars.map((bar) => ({ taskTitle: bar.taskTitle, minutes: bar.minutes }))).toEqual([
      { taskTitle: '整理周报', minutes: 90 },
      { taskTitle: '需求拆分', minutes: 90 },
    ]);
    expect(dataset.days[1].bars.map((bar) => ({ taskTitle: bar.taskTitle, minutes: bar.minutes }))).toEqual([
      { taskTitle: '回归测试', minutes: 45 },
      { taskTitle: '未归属 / 异常归属', minutes: 20 },
    ]);
    expect(dataset.legendItems.map((item) => item.label)).toEqual([
      '整理周报',
      '需求拆分',
      '回归测试',
      '未归属 / 异常归属',
    ]);
  });

  it('支持按标签、任务和日期范围组合筛选', () => {
    const dataset = buildWorkLogTimeChartDataset({
      tasks,
      items,
      taskTags,
      tagNames,
      filters: {
        startDate: '2026-01-06',
        endDate: '2026-01-06',
        selectedTaskIds: ['3'],
        selectedTagIds: ['10'],
      },
    });

    expect(dataset.totalMinutes).toBe(45);
    expect(dataset.days).toHaveLength(1);
    expect(dataset.days[0]).toMatchObject({
      dateKey: '2026-01-06',
      totalMinutes: 45,
    });
    expect(dataset.days[0].bars.map((bar) => ({ taskTitle: bar.taskTitle, minutes: bar.minutes }))).toEqual([
      { taskTitle: '回归测试', minutes: 45 },
    ]);
    expect(dataset.legendItems.map((item) => item.label)).toEqual(['回归测试']);
  });
});
