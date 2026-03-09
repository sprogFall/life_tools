'use client';

import Link from 'next/link';
import { useSearchParams } from 'next/navigation';

import { UserJsonEditor } from '@/components/user-json-editor';
import { DASHBOARD_PILL_BUTTON_MD } from '@/lib/button-styles';
import { buildUserRouteHref } from '@/lib/dashboard-routes';
import {
  updateDashboardTool,
  updateDashboardUserSnapshot,
} from '@/lib/api';
import { getActionErrorMessage } from '@/lib/error-utils';
import { formatTimestamp, getUserDisplayName } from '@/lib/format';
import type {
  DashboardActionResult,
  SaveDashboardSnapshotInput,
  SaveDashboardToolInput,
} from '@/lib/types';
import { useUserDetail } from '@/lib/use-user-detail';

export function UserJsonScreen() {
  const searchParams = useSearchParams();
  const userId = searchParams.get('userId')?.trim() ?? '';
  const requestedToolId = searchParams.get('tool')?.trim() ?? '';
  const { detail, setDetail, loading, error, loadDetail } = useUserDetail(userId);

  const saveSnapshotAction = async (
    input: SaveDashboardSnapshotInput,
  ): Promise<DashboardActionResult> => {
    try {
      const nextDetail = await updateDashboardUserSnapshot(input);
      setDetail(nextDetail);
      return { success: true, message: 'JSON 快照已保存到后端。' };
    } catch (saveError) {
      return { success: false, message: getActionErrorMessage(saveError) };
    }
  };

  const saveToolAction = async (
    input: SaveDashboardToolInput,
  ): Promise<DashboardActionResult> => {
    try {
      await updateDashboardTool(input);
      await loadDetail(input.userId);
      return { success: true, message: '当前工具 JSON 已保存到后端。' };
    } catch (saveError) {
      return { success: false, message: getActionErrorMessage(saveError) };
    }
  };

  if (loading) {
    return (
      <div className="rounded-4xl border border-slate-200 bg-white/85 px-6 py-16 text-center text-sm text-slate-500 shadow-panel">
        正在加载 JSON 管理页…
      </div>
    );
  }

  if (!detail || error) {
    return (
      <div className="rounded-4xl border border-rose-100 bg-rose-50/70 px-6 py-16 text-center shadow-panel">
        <p className="text-sm text-rose-600">{error ?? '未找到用户详情。'}</p>
        <Link
          href="/users"
          className={`mt-4 ${DASHBOARD_PILL_BUTTON_MD} bg-white text-rose-600 ring-1 ring-rose-200 hover:bg-rose-50`}
        >
          返回同步用户目录
        </Link>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <Link href="/users" className="text-sm font-medium text-brand-700 transition hover:text-brand-900">
              ← 返回同步用户目录
            </Link>
            <h1 className="mt-3 text-3xl font-semibold text-ink">{getUserDisplayName(detail.user)} · JSON 管理</h1>
            <p className="mt-2 font-mono text-sm text-slate-500">{detail.user.user_id}</p>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link
              scroll={false}
              href={buildUserRouteHref('/users/detail', detail.user.user_id, requestedToolId || null)}
              className={`${DASHBOARD_PILL_BUTTON_MD} border border-slate-200 bg-white text-slate-700 hover:border-brand-200 hover:bg-brand-50`}
            >
              返回结构化管理
            </Link>
          </div>
        </div>
        <div className="mt-5 grid gap-3 rounded-3xl bg-slate-50 px-4 py-3 text-sm text-slate-600 sm:grid-cols-3">
          <div>
            <p className="text-xs text-slate-400">服务端版本</p>
            <p className="mt-1 font-medium text-ink">r{detail.snapshot.server_revision}</p>
          </div>
          <div>
            <p className="text-xs text-slate-400">快照更新时间</p>
            <p className="mt-1 font-medium text-ink">{formatTimestamp(detail.snapshot.updated_at_ms)}</p>
          </div>
          <div>
            <p className="text-xs text-slate-400">工具数量</p>
            <p className="mt-1 font-medium text-ink">{detail.snapshot.tool_count} 个</p>
          </div>
        </div>
      </section>

      <UserJsonEditor
        userId={detail.user.user_id}
        toolsData={detail.snapshot.tools_data}
        initialToolId={requestedToolId || undefined}
        saveSnapshotAction={saveSnapshotAction}
        saveToolAction={saveToolAction}
      />
    </div>
  );
}
