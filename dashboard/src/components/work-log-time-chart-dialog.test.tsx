import React from 'react';
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { WorkLogTimeChartDialog } from '@/components/work-log-time-chart-dialog';

afterEach(() => cleanup());

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

const items = [
  { id: 1, task_id: 1, minutes: 60, work_date: jan5Noon, content: '同步周报' },
  { id: 2, task_id: 2, minutes: 90, work_date: jan5Afternoon, content: '拆分需求' },
  { id: 3, task_id: 1, minutes: 30, work_date: jan5Evening, content: '补充风险' },
  { id: 4, task_id: 3, minutes: 45, work_date: jan6Noon, content: '执行回归' },
];

describe('WorkLogTimeChartDialog', () => {
  it('展示单画布分组柱状图，图例可切换系列，并在悬浮时显示对应任务工时', () => {
    render(
      <WorkLogTimeChartDialog
        open
        tasks={tasks}
        items={items}
        taskTags={taskTags}
        tagNames={tagNames}
        onClose={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时记录柱状图' });

    expect(within(dialog).getByText('工时分组柱状图')).toBeInTheDocument();
    expect(within(dialog).getByRole('group', { name: '工时分组柱状图画布' })).toBeInTheDocument();
    expect(within(dialog).getByRole('group', { name: '分组柱状图图例' })).toBeInTheDocument();
    expect(within(dialog).getByText('整理周报')).toBeInTheDocument();
    expect(within(dialog).getByText('需求拆分')).toBeInTheDocument();
    expect(within(dialog).getByText('回归测试')).toBeInTheDocument();
    expect(within(dialog).getByText('2026-01-05')).toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: '工时柱 2026-01-05 需求拆分 90 分钟' })).toBeInTheDocument();

    fireEvent.click(within(dialog).getByRole('button', { name: '切换图例 需求拆分' }));
    expect(within(dialog).queryByRole('button', { name: '工时柱 2026-01-05 需求拆分 90 分钟' })).not.toBeInTheDocument();

    fireEvent.click(within(dialog).getByRole('button', { name: '切换图例 需求拆分' }));
    expect(within(dialog).getByRole('button', { name: '工时柱 2026-01-05 需求拆分 90 分钟' })).toBeInTheDocument();

    fireEvent.mouseEnter(within(dialog).getByRole('button', { name: '工时柱 2026-01-05 需求拆分 90 分钟' }));

    const tooltip = screen.getByRole('tooltip', { name: '工时提示 2026-01-05 需求拆分' });
    expect(within(tooltip).getByText('需求拆分')).toBeInTheDocument();
    expect(within(tooltip).getByText('90 分钟')).toBeInTheDocument();
    expect(within(tooltip).getByText('2026-01-05')).toBeInTheDocument();
  });

  it('支持按标签、任务和日期范围筛选柱状图', () => {
    render(
      <WorkLogTimeChartDialog
        open
        tasks={tasks}
        items={items}
        taskTags={taskTags}
        tagNames={tagNames}
        onClose={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时记录柱状图' });

    fireEvent.click(within(dialog).getByRole('button', { name: '按任务标签筛选' }));
    const tagPanel = within(dialog).getByRole('group', { name: '工时图标签筛选面板' });
    fireEvent.click(within(tagPanel).getByRole('checkbox', { name: '项目A' }));

    expect(within(dialog).queryByRole('button', { name: '工时柱 2026-01-05 需求拆分 90 分钟' })).not.toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: '工时柱 2026-01-05 整理周报 90 分钟' })).toBeInTheDocument();

    fireEvent.change(within(dialog).getByLabelText('开始日期'), { target: { value: '2026-01-06' } });
    fireEvent.change(within(dialog).getByLabelText('结束日期'), { target: { value: '2026-01-06' } });

    expect(within(dialog).queryByText('2026-01-05')).not.toBeInTheDocument();
    expect(within(dialog).getByText('2026-01-06')).toBeInTheDocument();

    fireEvent.click(within(dialog).getByRole('button', { name: '按任务筛选' }));
    const taskPanel = within(dialog).getByRole('group', { name: '工时图任务筛选面板' });
    fireEvent.click(within(taskPanel).getByRole('checkbox', { name: '回归测试' }));

    expect(within(dialog).getByRole('button', { name: '工时柱 2026-01-06 回归测试 45 分钟' })).toBeInTheDocument();
    expect(within(dialog).queryByRole('button', { name: '工时柱 2026-01-06 整理周报 45 分钟' })).not.toBeInTheDocument();
  });

  it('支持切换全屏查看图表', () => {
    render(
      <WorkLogTimeChartDialog
        open
        tasks={tasks}
        items={items}
        taskTags={taskTags}
        tagNames={tagNames}
        onClose={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时记录柱状图' });
    expect(dialog).toHaveAttribute('data-fullscreen', 'false');

    fireEvent.click(within(dialog).getByRole('button', { name: '进入全屏' }));

    expect(screen.getByRole('dialog', { name: '工时记录柱状图' })).toHaveAttribute('data-fullscreen', 'true');
    expect(within(screen.getByRole('dialog', { name: '工时记录柱状图' })).getByRole('button', { name: '退出全屏' })).toBeInTheDocument();
  });
});
