import { render, screen } from '@testing-library/react';
import type { ReactNode } from 'react';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { UserDetailScreen } from '@/components/user-detail-screen';
import type { DashboardUserDetailResponse } from '@/lib/types';

const useSearchParamsMock = vi.fn();
const useUserDetailMock = vi.fn();

function hrefToString(href: string | { pathname?: string; query?: Record<string, string> }) {
  if (typeof href === 'string') {
    return href;
  }

  const pathname = href.pathname ?? '';
  const query = href.query ? new URLSearchParams(href.query).toString() : '';
  return query ? `${pathname}?${query}` : pathname;
}

vi.mock('next/navigation', () => ({
  useSearchParams: () => useSearchParamsMock(),
}));

vi.mock('next/link', () => ({
  default: ({ href, scroll, children, ...props }: { href: string | { pathname?: string; query?: Record<string, string> }; scroll?: boolean; children: ReactNode }) => (
    <a href={hrefToString(href)} data-scroll={scroll === false ? 'false' : 'true'} {...props}>
      {children}
    </a>
  ),
}));

vi.mock('@/lib/use-user-detail', () => ({
  useUserDetail: (...args: unknown[]) => useUserDetailMock(...args),
}));

vi.mock('@/components/tool-workspace', () => ({
  ToolWorkspace: () => <div>tool workspace</div>,
}));

vi.mock('@/components/user-profile-editor', () => ({
  UserProfileEditor: () => <div>profile editor</div>,
}));

vi.mock('@/lib/tool-relations', () => ({
  buildRelationContext: () => ({}),
  formatSyncDecisionLabel: (value: string) => value,
}));

const detail: DashboardUserDetailResponse = {
  success: true,
  user: {
    user_id: 'sync_alpha',
    display_name: 'Alpha',
    notes: 'demo',
    is_enabled: true,
    created_at_ms: 1,
    updated_at_ms: 2,
    last_seen_at_ms: 3,
    snapshot: {
      has_snapshot: true,
      server_revision: 7,
      updated_at_ms: 1700000000000,
      tool_count: 2,
      tool_ids: ['work_log', 'stockpile_assistant'],
      total_item_count: 3,
      tool_summaries: [
        {
          tool_id: 'work_log',
          version: 5,
          total_items: 2,
          section_counts: { tasks: 1 },
        },
        {
          tool_id: 'stockpile_assistant',
          version: 4,
          total_items: 1,
          section_counts: { items: 1 },
        },
      ],
    },
  },
  snapshot: {
    has_snapshot: true,
    server_revision: 7,
    updated_at_ms: 1700000000000,
    tool_count: 2,
    tool_ids: ['work_log', 'stockpile_assistant'],
    total_item_count: 3,
    tool_summaries: [
      {
        tool_id: 'work_log',
        version: 5,
        total_items: 2,
        section_counts: { tasks: 1 },
      },
      {
        tool_id: 'stockpile_assistant',
        version: 4,
        total_items: 1,
        section_counts: { items: 1 },
      },
    ],
    tools_data: {
      work_log: {
        version: 5,
        data: { tasks: [{ id: 1, title: '整理周报' }] },
      },
      stockpile_assistant: {
        version: 4,
        data: { items: [{ id: 2, name: '牛奶' }] },
      },
    },
  },
  recent_records: [
    {
      id: 11,
      user_id: 'sync_alpha',
      protocol_version: 1,
      decision: 'merged',
      server_time: 1700000000000,
      client_time: 1700000000000,
      client_updated_at_ms: 1700000000000,
      server_updated_at_ms_before: 1700000000000,
      server_updated_at_ms_after: 1700000000000,
      server_revision_before: 6,
      server_revision_after: 7,
      diff_summary: {},
    },
  ],
};

describe('UserDetailScreen', () => {
  beforeEach(() => {
    useSearchParamsMock.mockReturnValue(new URLSearchParams('userId=sync_alpha&tool=work_log'));
    useUserDetailMock.mockReturnValue({
      detail,
      loading: false,
      error: null,
      loadDetail: vi.fn(),
    });
  });

  it('切换工具使用无滚动客户端导航，避免桌面端回到页面顶部', () => {
    render(<UserDetailScreen />);

    const toolLink = screen.getByRole('link', { name: /囤货助手/ });

    expect(toolLink).toHaveAttribute('href', '/users/detail?userId=sync_alpha&tool=stockpile_assistant');
    expect(toolLink).toHaveAttribute('data-scroll', 'false');
  });
});
