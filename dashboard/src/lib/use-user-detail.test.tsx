import { act, renderHook, waitFor } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';

import { useUserDetail } from '@/lib/use-user-detail';
import type { DashboardUserDetailResponse } from '@/lib/types';

const fetchDashboardUserDetailMock = vi.fn();

vi.mock('@/lib/api', () => ({
  fetchDashboardUserDetail: (...args: unknown[]) => fetchDashboardUserDetailMock(...args),
}));

function createDetail(serverRevision: number): DashboardUserDetailResponse {
  return {
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
        server_revision: serverRevision,
        updated_at_ms: 1000 + serverRevision,
        tool_count: 1,
        tool_ids: ['work_log'],
        total_item_count: 1,
        tool_summaries: [
          {
            tool_id: 'work_log',
            version: serverRevision,
            total_items: 1,
            section_counts: { tasks: 1 },
          },
        ],
      },
    },
    snapshot: {
      has_snapshot: true,
      server_revision: serverRevision,
      updated_at_ms: 1000 + serverRevision,
      tool_count: 1,
      tool_ids: ['work_log'],
      total_item_count: 1,
      tool_summaries: [
        {
          tool_id: 'work_log',
          version: serverRevision,
          total_items: 1,
          section_counts: { tasks: 1 },
        },
      ],
      tools_data: {
        work_log: {
          version: serverRevision,
          data: {
            tasks: [{ id: 1, title: `任务 r${serverRevision}` }],
          },
        },
      },
    },
    recent_records: [],
  };
}

function createDeferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (error?: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

describe('useUserDetail', () => {
  it('只采纳最新一次详情响应，避免旧请求覆盖新数据', async () => {
    const first = createDeferred<DashboardUserDetailResponse>();
    const second = createDeferred<DashboardUserDetailResponse>();

    fetchDashboardUserDetailMock
      .mockReturnValueOnce(first.promise)
      .mockReturnValueOnce(second.promise);

    const { result } = renderHook(() => useUserDetail('u1'));

    await waitFor(() => {
      expect(fetchDashboardUserDetailMock).toHaveBeenCalledTimes(1);
    });

    act(() => {
      void result.current.loadDetail('u1');
    });

    await waitFor(() => {
      expect(fetchDashboardUserDetailMock).toHaveBeenCalledTimes(2);
    });

    await act(async () => {
      second.resolve(createDetail(2));
      await second.promise;
    });

    await waitFor(() => {
      expect(result.current.detail?.snapshot.server_revision).toBe(2);
    });

    await act(async () => {
      first.resolve(createDetail(1));
      await first.promise;
    });

    expect(result.current.detail?.snapshot.server_revision).toBe(2);
    expect(result.current.loading).toBe(false);
    expect(result.current.error).toBeNull();
  });
});
