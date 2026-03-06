import React from 'react';
import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { ToolWorkspace } from '@/components/tool-workspace';
import type { DashboardToolPayload } from '@/lib/types';

const tool: DashboardToolPayload = {
  tool_id: 'work_log',
  version: 1,
  summary: {
    tool_id: 'work_log',
    version: 1,
    total_items: 3,
    section_counts: {
      tasks: 1,
      time_entries: 1,
      operation_logs: 1,
    },
  },
  data: {
    tasks: [
      {
        id: 1,
        title: '整理周报',
        description: '补充风险说明',
        status: 1,
        estimated_minutes: 60,
        created_at: 1731000000000,
        updated_at: 1731000001000,
      },
    ],
    time_entries: [
      {
        id: 1,
        task_id: 1,
        minutes: 60,
        content: '完成文案整理',
        work_date: 1731000000000,
        created_at: 1731000000000,
        updated_at: 1731000001000,
      },
    ],
    operation_logs: [],
  },
};

describe('ToolWorkspace', () => {
  it('渲染工具摘要、区块标签和保存按钮', () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    expect(screen.getByText('工作记录')).toBeInTheDocument();
    expect(screen.getByText('共管理 3 条记录')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'tasks (1)' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'time_entries (1)' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '保存到后端' })).toBeInTheDocument();
  });
});
