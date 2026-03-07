import React from 'react';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ToolWorkspace } from '@/components/tool-workspace';
import { buildRelationContext } from '@/lib/tool-relations';
import type { DashboardToolPayload, DashboardUserDetailResponse } from '@/lib/types';

afterEach(() => cleanup());

const detail: DashboardUserDetailResponse = {
  success: true,
  user: {
    user_id: 'u1',
    display_name: '主账号',
    notes: '',
    is_enabled: true,
    created_at_ms: 1,
    updated_at_ms: 2,
    last_seen_at_ms: 3,
    snapshot: {
      has_snapshot: true,
      server_revision: 1,
      updated_at_ms: 4,
      tool_count: 1,
      tool_ids: ['work_log'],
      total_item_count: 2,
      tool_summaries: [],
    },
  },
  snapshot: {
    has_snapshot: true,
    server_revision: 1,
    updated_at_ms: 4,
    tool_count: 2,
    tool_ids: ['work_log', 'tag_manager'],
    total_item_count: 4,
    tool_summaries: [],
    tools_data: {
      work_log: {
        version: 1,
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
          task_tags: [],
        },
      },
      tag_manager: {
        version: 1,
        data: {
          tags: [{ id: 10, name: '项目A' }],
          tool_tags: [],
        },
      },
    },
  },
  recent_records: [],
};

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
  data: detail.snapshot.tools_data.work_log.data,
};

describe('ToolWorkspace', () => {
  it('渲染友好关联文案，并为关联字段提供选择器', () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    expect(screen.getByText('工作记录')).toBeInTheDocument();
    expect(screen.getByText('共管理 3 条记录')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'tasks (1)' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'time_entries (1)' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '保存到后端' })).toBeInTheDocument();

    const timeEntriesTab = screen.getByRole('button', { name: 'time_entries (1)' });
    fireEvent.click(timeEntriesTab);

    expect(screen.getAllByText('整理周报').length).toBeGreaterThan(0);
    expect(screen.getByRole('combobox', { name: '任务' })).toHaveDisplayValue('整理周报');
  });

  it('对敏感字段使用只读限制，例如主键 id 不允许直接修改', () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    expect(screen.getByRole('textbox', { name: '标题' })).toHaveValue('整理周报');
    expect(screen.getByRole('spinbutton', { name: 'ID' })).toBeDisabled();
    expect(screen.getByLabelText('创建时间')).toBeDisabled();
  });
});
