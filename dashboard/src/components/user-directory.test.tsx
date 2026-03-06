import React from 'react';
import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';

import { UserDirectory } from '@/components/user-directory';
import type { DashboardUserSummary } from '@/lib/types';

const users: DashboardUserSummary[] = [
  {
    user_id: 'sync_alpha',
    display_name: 'Alpha 家庭',
    notes: '用于工作记录',
    is_enabled: true,
    created_at_ms: 1,
    updated_at_ms: 2,
    last_seen_at_ms: 1731000000000,
    snapshot: {
      has_snapshot: true,
      server_revision: 5,
      updated_at_ms: 1731000000000,
      tool_count: 2,
      tool_ids: ['work_log', 'tag_manager'],
      total_item_count: 12,
      tool_summaries: [],
    },
  },
  {
    user_id: 'sync_beta',
    display_name: '',
    notes: '',
    is_enabled: false,
    created_at_ms: 1,
    updated_at_ms: 2,
    last_seen_at_ms: null,
    snapshot: {
      has_snapshot: false,
      server_revision: 0,
      updated_at_ms: 0,
      tool_count: 0,
      tool_ids: [],
      total_item_count: 0,
      tool_summaries: [],
    },
  },
];

describe('UserDirectory', () => {
  it('渲染用户卡片、启用状态和快照信息', () => {
    render(<UserDirectory users={users} />);

    expect(screen.getByText('Alpha 家庭')).toBeInTheDocument();
    expect(screen.getByText('sync_beta')).toBeInTheDocument();
    expect(screen.getByText('已启用')).toBeInTheDocument();
    expect(screen.getByText('已停用')).toBeInTheDocument();
    expect(screen.getByText('同步工具 2 个')).toBeInTheDocument();
    expect(screen.getByText('暂无快照')).toBeInTheDocument();
  });
});
