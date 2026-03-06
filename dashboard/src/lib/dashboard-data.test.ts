import { describe, expect, it } from 'vitest';

import { buildOverviewStats, resolveSelectedToolId } from '@/lib/dashboard-data';
import type { DashboardUserSummary } from '@/lib/types';

const sampleUsers: DashboardUserSummary[] = [
  {
    user_id: 'u1',
    display_name: '主账号',
    notes: '',
    is_enabled: true,
    created_at_ms: 1,
    updated_at_ms: 2,
    last_seen_at_ms: 1731000000000,
    snapshot: {
      has_snapshot: true,
      server_revision: 3,
      updated_at_ms: 1731000000000,
      tool_count: 2,
      tool_ids: ['work_log', 'stockpile_assistant'],
      total_item_count: 14,
      tool_summaries: [],
    },
  },
  {
    user_id: 'u2',
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

describe('dashboard-data', () => {
  it('汇总概览统计', () => {
    expect(buildOverviewStats(sampleUsers)).toEqual({
      totalUsers: 2,
      enabledUsers: 1,
      activeUsers: 1,
      syncedTools: 2,
      managedRecords: 14,
    });
  });

  it('优先选择有效工具，否则回退到第一个工具', () => {
    expect(resolveSelectedToolId('stockpile_assistant', ['work_log', 'stockpile_assistant'])).toBe(
      'stockpile_assistant',
    );
    expect(resolveSelectedToolId('unknown', ['work_log', 'stockpile_assistant'])).toBe('work_log');
    expect(resolveSelectedToolId(null, [])).toBeNull();
  });
});
