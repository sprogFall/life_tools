import React from 'react';
import { act, cleanup, fireEvent, render, screen, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { WorkLogTimeCanvasDialog } from '@/components/work-log-time-canvas-dialog';

afterEach(() => {
  window.localStorage.clear();
  vi.useRealTimers();
  cleanup();
});

const tasks = [
  {
    id: 1,
    title: '整理周报',
    description: '补充风险说明并同步里程碑',
    status: 1,
    estimated_minutes: 60,
    sort_index: 1,
    is_pinned: true,
  },
  {
    id: 2,
    title: '需求拆分',
    description: '重新梳理历史工时归属',
    status: 0,
    estimated_minutes: 90,
    sort_index: 2,
    is_pinned: false,
  },
];

const taskTags = [
  { task_id: 1, tag_id: 10 },
  { task_id: 2, tag_id: 11 },
];

const tagNames = {
  10: '项目A',
  11: '项目B',
};

const items = [
  {
    id: 1,
    task_id: 1,
    minutes: 60,
    content: '完成文案整理',
    work_date: 1731000000000,
    created_at: 1731000000000,
    updated_at: 1731000001000,
  },
  {
    id: 2,
    task_id: 1,
    minutes: 30,
    content: '补录会议纪要',
    work_date: 1731086400000,
    created_at: 1731086400000,
    updated_at: 1731086401000,
  },
];

describe('WorkLogTimeCanvasDialog', () => {
  it('支持在画布中拖拽改归属，并可撤销上次调整', () => {
    render(
      <WorkLogTimeCanvasDialog
        open
        tasks={tasks}
        items={items}
        onClose={vi.fn()}
        onCommit={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    const sourceGroup = within(dialog).getByRole('group', { name: '工时画布节点 整理周报' });
    const targetGroup = within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' });
    const entryCard = within(dialog).getByRole('button', { name: '工时卡片 补录会议纪要' });

    fireEvent.dragStart(entryCard);
    fireEvent.dragOver(targetGroup);
    fireEvent.drop(targetGroup);

    expect(within(targetGroup).getByText('补录会议纪要')).toBeInTheDocument();
    expect(within(dialog).getByText('已将“补录会议纪要”归属到“需求拆分”')).toBeInTheDocument();

    fireEvent.click(within(dialog).getByRole('button', { name: '撤销上次调整' }));

    expect(within(sourceGroup).getByText('补录会议纪要')).toBeInTheDocument();
    expect(within(dialog).getByText('已撤销“补录会议纪要”的归属调整，恢复到“整理周报”')).toBeInTheDocument();
  });

  it('未归属节点只用于展示异常数据，不能作为新的拖拽目标', () => {
    render(
      <WorkLogTimeCanvasDialog
        open
        tasks={tasks}
        items={items}
        onClose={vi.fn()}
        onCommit={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    const sourceGroup = within(dialog).getByRole('group', { name: '工时画布节点 整理周报' });
    const orphanGroup = within(dialog).getByRole('group', { name: '工时画布节点 未归属 / 异常归属' });
    const entryCard = within(dialog).getByRole('button', { name: '工时卡片 补录会议纪要' });

    expect(within(orphanGroup).getByText('这里仅展示异常归属记录，不能作为新的归属目标。')).toBeInTheDocument();

    fireEvent.dragStart(entryCard);
    fireEvent.dragOver(orphanGroup);
    fireEvent.drop(orphanGroup);

    expect(within(sourceGroup).getByText('补录会议纪要')).toBeInTheDocument();
    expect(within(orphanGroup).queryByText('补录会议纪要')).not.toBeInTheDocument();
  });

  it('工时卡片悬浮 0.5 秒后显示详情浮窗，移出后隐藏', () => {
    vi.useFakeTimers();

    render(
      <WorkLogTimeCanvasDialog
        open
        tasks={tasks}
        items={items}
        onClose={vi.fn()}
        onCommit={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    const entryCard = within(dialog).getByRole('button', { name: '工时卡片 补录会议纪要' });

    fireEvent.mouseEnter(entryCard);

    act(() => {
      vi.advanceTimersByTime(499);
    });
    expect(screen.queryByRole('tooltip', { name: '工时详情浮窗 补录会议纪要' })).not.toBeInTheDocument();

    act(() => {
      vi.advanceTimersByTime(1);
    });

    const tooltip = screen.getByRole('tooltip', { name: '工时详情浮窗 补录会议纪要' });
    expect(within(tooltip).queryByText('工时详情')).not.toBeInTheDocument();
    expect(within(tooltip).getByText('内容全文')).toBeInTheDocument();
    expect(within(tooltip).getByText('记录 ID')).toBeInTheDocument();
    expect(within(tooltip).getByText('最近更新时间')).toBeInTheDocument();
    expect(within(tooltip).getByText('补录会议纪要')).toBeInTheDocument();
    expect(within(tooltip).queryByText(/任务：整理周报/)).not.toBeInTheDocument();
    expect(within(tooltip).queryByText('30 分钟')).not.toBeInTheDocument();

    fireEvent.mouseLeave(entryCard);

    expect(screen.queryByRole('tooltip', { name: '工时详情浮窗 补录会议纪要' })).not.toBeInTheDocument();
  });

  it('任务标题悬浮 0.5 秒后显示状态、标签等详情信息', () => {
    vi.useFakeTimers();

    render(
      <WorkLogTimeCanvasDialog
        open
        tasks={tasks}
        items={items}
        taskTags={taskTags}
        tagNames={tagNames}
        onClose={vi.fn()}
        onCommit={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    const taskTitleTrigger = within(dialog).getByLabelText('任务标题 整理周报');

    fireEvent.mouseEnter(taskTitleTrigger);

    act(() => {
      vi.advanceTimersByTime(500);
    });

    const tooltip = screen.getByRole('tooltip', { name: '任务详情浮窗 整理周报' });
    expect(within(tooltip).getByText('任务状态')).toBeInTheDocument();
    expect(within(tooltip).getByText('进行中')).toBeInTheDocument();
    expect(within(tooltip).getByText('任务标签')).toBeInTheDocument();
    expect(within(tooltip).getByText('项目A')).toBeInTheDocument();
    expect(within(tooltip).getByText('补充风险说明并同步里程碑')).toBeInTheDocument();
    expect(within(tooltip).getByText('预估 60 分钟')).toBeInTheDocument();
    expect(within(tooltip).getByText('2 条记录')).toBeInTheDocument();

    fireEvent.mouseLeave(taskTitleTrigger);

    expect(screen.queryByRole('tooltip', { name: '任务详情浮窗 整理周报' })).not.toBeInTheDocument();
  });

  it('支持按任务状态和标签多选筛选画布节点', () => {
    const multiSelectTasks = [
      { id: 1, title: '整理周报', status: 1, estimated_minutes: 60, sort_index: 1, is_pinned: true },
      { id: 2, title: '需求拆分', status: 0, estimated_minutes: 90, sort_index: 2, is_pinned: false },
      { id: 3, title: '交付复盘', status: 2, estimated_minutes: 45, sort_index: 3, is_pinned: false },
    ];
    const multiSelectItems = [
      { id: 1, task_id: 1, minutes: 60, content: '完成文案整理', work_date: 1731000000000 },
      { id: 2, task_id: 2, minutes: 30, content: '补录会议纪要', work_date: 1731086400000 },
      { id: 3, task_id: 3, minutes: 45, content: '归档验收记录', work_date: 1731172800000 },
    ];
    const multiSelectTaskTags = [
      { task_id: 1, tag_id: 10 },
      { task_id: 2, tag_id: 11 },
      { task_id: 3, tag_id: 12 },
    ];
    const multiSelectTagNames = {
      10: '项目A',
      11: '项目B',
      12: '项目C',
    };

    render(
      <WorkLogTimeCanvasDialog
        open
        tasks={multiSelectTasks}
        items={multiSelectItems}
        taskTags={multiSelectTaskTags}
        tagNames={multiSelectTagNames}
        onClose={vi.fn()}
        onCommit={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    expect(within(dialog).getByRole('group', { name: '工时画布节点 整理周报' })).toBeInTheDocument();
    expect(within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' })).toBeInTheDocument();
    expect(within(dialog).getByRole('group', { name: '工时画布节点 交付复盘' })).toBeInTheDocument();

    fireEvent.click(within(dialog).getByRole('button', { name: '按任务状态筛选' }));
    const statusPanel = within(dialog).getByRole('group', { name: '状态筛选面板' });
    fireEvent.click(within(statusPanel).getByRole('checkbox', { name: '进行中' }));
    fireEvent.click(within(statusPanel).getByRole('checkbox', { name: '待办' }));

    expect(within(dialog).getByRole('group', { name: '工时画布节点 整理周报' })).toBeInTheDocument();
    expect(within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' })).toBeInTheDocument();
    expect(within(dialog).queryByRole('group', { name: '工时画布节点 交付复盘' })).not.toBeInTheDocument();
    expect(within(dialog).queryByRole('group', { name: '工时画布节点 未归属 / 异常归属' })).not.toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: /按任务状态筛选/ })).toHaveTextContent('已选 2 项');

    fireEvent.click(within(dialog).getByRole('button', { name: '按任务标签筛选' }));
    const tagPanel = within(dialog).getByRole('group', { name: '标签筛选面板' });
    fireEvent.click(within(tagPanel).getByRole('checkbox', { name: '项目A' }));
    fireEvent.click(within(tagPanel).getByRole('checkbox', { name: '项目C' }));

    expect(within(dialog).getByRole('group', { name: '工时画布节点 整理周报' })).toBeInTheDocument();
    expect(within(dialog).queryByRole('group', { name: '工时画布节点 需求拆分' })).not.toBeInTheDocument();
    expect(within(dialog).queryByRole('group', { name: '工时画布节点 交付复盘' })).not.toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: /按任务标签筛选/ })).toHaveTextContent('已选 2 项');
  });


  it('通过 portal 渲染弹层，并支持全屏切换', () => {
    const { container } = render(
      <WorkLogTimeCanvasDialog
        open
        tasks={tasks}
        items={items}
        onClose={vi.fn()}
        onCommit={vi.fn()}
      />,
    );

    expect(container.querySelector('[data-dialog-overlay="true"]')).toBeNull();
    expect(document.body.querySelector('[data-dialog-overlay="true"]')).toBeInTheDocument();

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    expect(dialog).toHaveAttribute('data-fullscreen', 'false');
    expect(dialog).toHaveAttribute('data-theme', 'dark');

    fireEvent.click(within(dialog).getByRole('button', { name: '切换到浅色模式' }));

    expect(screen.getByRole('dialog', { name: '工时归属整理画布' })).toHaveAttribute('data-theme', 'light');
    expect(within(screen.getByRole('dialog', { name: '工时归属整理画布' })).getByRole('button', { name: '切换到深色模式' })).toBeInTheDocument();

    fireEvent.click(within(screen.getByRole('dialog', { name: '工时归属整理画布' })).getByRole('button', { name: '进入全屏' }));

    expect(screen.getByRole('dialog', { name: '工时归属整理画布' })).toHaveAttribute('data-fullscreen', 'true');
    expect(within(screen.getByRole('dialog', { name: '工时归属整理画布' })).getByRole('button', { name: '退出全屏' })).toBeInTheDocument();
    expect(screen.queryByText('沉浸式工时归属整理')).not.toBeInTheDocument();
    expect(screen.queryByText(/像白板一样在画布中浏览任务与工时卡片/)).not.toBeInTheDocument();
    const fullscreenDialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    expect(within(fullscreenDialog).getByRole('textbox', { name: '筛选任务或工时' })).toBeInTheDocument();

    const toolbar = fullscreenDialog.querySelector('[data-filter-toolbar="true"]');
    expect(toolbar).not.toBeNull();

    fireEvent.click(within(fullscreenDialog).getByRole('button', { name: '按任务状态筛选' }));
    const statusPanel = within(fullscreenDialog).getByRole('group', { name: '状态筛选面板' });
    expect(toolbar?.contains(statusPanel)).toBe(false);

    fireEvent.click(within(statusPanel).getByRole('checkbox', { name: '进行中' }));
    expect(within(fullscreenDialog).getByRole('group', { name: '工时画布节点 整理周报' })).toBeInTheDocument();
    expect(within(fullscreenDialog).queryByRole('group', { name: '工时画布节点 需求拆分' })).not.toBeInTheDocument();
  });

  it('记忆主题选择，并在重新打开后恢复', async () => {
    const { unmount } = render(
      <WorkLogTimeCanvasDialog
        open
        tasks={tasks}
        items={items}
        onClose={vi.fn()}
        onCommit={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    expect(dialog).toHaveAttribute('data-theme', 'dark');

    fireEvent.click(within(dialog).getByRole('button', { name: '切换到浅色模式' }));

    expect(window.localStorage.getItem('dashboard.work-log-canvas-theme')).toBe('light');
    expect(screen.getByRole('dialog', { name: '工时归属整理画布' })).toHaveAttribute('data-theme', 'light');

    unmount();

    render(
      <WorkLogTimeCanvasDialog
        open
        tasks={tasks}
        items={items}
        onClose={vi.fn()}
        onCommit={vi.fn()}
      />,
    );

    expect(screen.getByRole('dialog', { name: '工时归属整理画布' })).toHaveAttribute('data-theme', 'light');
    expect(screen.getByRole('button', { name: '切换到深色模式' })).toBeInTheDocument();
  });

  it('支持缩放、拖动画布并重置视图', () => {
    render(
      <WorkLogTimeCanvasDialog
        open
        tasks={tasks}
        items={items}
        onClose={vi.fn()}
        onCommit={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    const viewport = within(dialog).getByLabelText('工时归属画布视口');

    expect(within(dialog).getByText('缩放 100% · 偏移 X 0 · 偏移 Y 0')).toBeInTheDocument();

    fireEvent.click(within(dialog).getByRole('button', { name: '放大视图' }));
    expect(within(dialog).getByText('缩放 110% · 偏移 X 0 · 偏移 Y 0')).toBeInTheDocument();

    fireEvent.mouseDown(viewport, { clientX: 20, clientY: 30 });
    fireEvent.mouseMove(window, { clientX: 80, clientY: 90 });
    fireEvent.mouseUp(window);

    expect(within(dialog).getByText('缩放 110% · 偏移 X 60 · 偏移 Y 60')).toBeInTheDocument();

    fireEvent.click(within(dialog).getByRole('button', { name: '重置视图' }));

    expect(within(dialog).getByText('缩放 100% · 偏移 X 0 · 偏移 Y 0')).toBeInTheDocument();
  });

  it('支持拖拽任务模块调整布局，方便整理工时归属', () => {
    render(
      <WorkLogTimeCanvasDialog
        open
        tasks={tasks}
        items={items}
        onClose={vi.fn()}
        onCommit={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    const taskGroup = within(dialog).getByRole('group', { name: '工时画布节点 整理周报' });
    const dragHandle = within(taskGroup).getByLabelText('拖拽任务模块边框 整理周报');
    const dragGlow = taskGroup.querySelector('[data-node-drag-glow="true"]');

    expect(within(taskGroup).queryByText('拖动布局')).not.toBeInTheDocument();
    expect(dragGlow).toHaveClass('transition-all', 'duration-200');

    expect(taskGroup.style.left).toBe('96px');
    expect(taskGroup.style.top).toBe('96px');

    fireEvent.mouseDown(dragHandle, { clientX: 100, clientY: 120 });
    fireEvent.mouseMove(window, { clientX: 180, clientY: 210 });
    fireEvent.mouseUp(window);

    expect(taskGroup.style.left).toBe('176px');
    expect(taskGroup.style.top).toBe('186px');
  });

  it('支持从任务框右下角圆角拖拽缩放单个任务树，内部内容同步缩放', () => {
    render(
      <WorkLogTimeCanvasDialog
        open
        tasks={tasks}
        items={items}
        onClose={vi.fn()}
        onCommit={vi.fn()}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    const taskGroup = within(dialog).getByRole('group', { name: '工时画布节点 整理周报' });
    const resizeHandle = within(taskGroup).getByLabelText('缩放任务树边框 整理周报');
    const resizeGlow = taskGroup.querySelector('[data-node-resize-glow="true"]');

    expect(within(taskGroup).getByText('节点 100%')).toBeInTheDocument();
    expect(resizeGlow).toHaveClass('transition-all', 'duration-200');

    fireEvent.mouseDown(resizeHandle, { clientX: 320, clientY: 412 });
    fireEvent.mouseMove(window, { clientX: 384, clientY: 494 });
    fireEvent.mouseUp(window);

    expect(within(taskGroup).getByText('节点 120%')).toBeInTheDocument();
    expect(taskGroup.style.width).toBe('384px');
    expect(taskGroup.style.height).toBe('494px');
    expect(taskGroup.querySelector('[data-node-content="true"]')).toHaveStyle({
      transform: 'scale(1.2)',
    });
  });

  it('仅在点击保存调整时提交临时改动', () => {
    const handleCommit = vi.fn();
    const handleClose = vi.fn();

    render(
      <WorkLogTimeCanvasDialog
        open
        tasks={tasks}
        items={items}
        onClose={handleClose}
        onCommit={handleCommit}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    fireEvent.dragStart(within(dialog).getByRole('button', { name: '工时卡片 补录会议纪要' }));
    fireEvent.dragOver(within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' }));
    fireEvent.drop(within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' }));

    fireEvent.click(within(dialog).getByRole('button', { name: '取消调整' }));

    expect(handleCommit).not.toHaveBeenCalled();
    expect(handleClose).toHaveBeenCalledTimes(1);
  });

  it('支持直接把画布改动保存，避免停留在多余草稿动作上', () => {
    const handleCommit = vi.fn();
    const handleCommitToBackend = vi.fn();
    const handleClose = vi.fn();

    render(
      <WorkLogTimeCanvasDialog
        open
        tasks={tasks}
        items={items}
        onClose={handleClose}
        onCommit={handleCommit}
        onCommitToBackend={handleCommitToBackend}
      />,
    );

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    fireEvent.dragStart(within(dialog).getByRole('button', { name: '工时卡片 补录会议纪要' }));
    fireEvent.dragOver(within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' }));
    fireEvent.drop(within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' }));

    expect(within(dialog).queryByRole('button', { name: '保存到草稿' })).not.toBeInTheDocument();
    fireEvent.click(within(dialog).getByRole('button', { name: '保存' }));

    expect(handleCommit).not.toHaveBeenCalled();
    expect(handleCommitToBackend).toHaveBeenCalledTimes(1);
    expect(handleCommitToBackend).toHaveBeenCalledWith(
      expect.arrayContaining([expect.objectContaining({ id: 2, task_id: 2 })]),
    );
    expect(handleClose).toHaveBeenCalledTimes(1);
  });
});
