'use client';

import Link from 'next/link';
import { useMemo } from 'react';
import { useSearchParams } from 'next/navigation';

import { ToolWorkspace } from '@/components/tool-workspace';
import { UserProfileEditor } from '@/components/user-profile-editor';
import { buildToolPayload, resolveSelectedToolId } from '@/lib/dashboard-data';
import { buildUserRouteHref } from '@/lib/dashboard-routes';
import {
  updateDashboardTool,
  updateDashboardUserProfile,
} from '@/lib/api';
import { getActionErrorMessage } from '@/lib/error-utils';
import { formatTimestamp, getUserDisplayName } from '@/lib/format';
import { getToolConfig } from '@/lib/tool-config';
import {
  buildRelationContext,
  formatSyncDecisionLabel,
} from '@/lib/tool-relations';
import type {
  DashboardActionResult,
  SaveDashboardToolInput,
  SaveDashboardUserProfileInput,
} from '@/lib/types';
import { useUserDetail } from '@/lib/use-user-detail';

export function UserDetailScreen() {
  const searchParams = useSearchParams();
  const userId = searchParams.get('userId')?.trim() ?? '';
  const requestedToolId = searchParams.get('tool');
  const { detail, loading, error, loadDetail } = useUserDetail(userId);

  const selectedToolId = detail
    ? resolveSelectedToolId(requestedToolId, detail.snapshot.tool_ids)
    : null;
  const selectedTool = detail && selectedToolId ? buildToolPayload(detail, selectedToolId) : null;
  const selectedToolSummary =
    detail?.snapshot.tool_summaries.find((item) => item.tool_id === selectedToolId) ?? null;
  const displayName = detail ? getUserDisplayName(detail.user) : '';
  const relationContext = useMemo(
    () => (detail ? buildRelationContext(detail) : undefined),
    [detail],
  );

  const saveUserAction = async (
    input: SaveDashboardUserProfileInput,
  ): Promise<DashboardActionResult> => {
    try {
      await updateDashboardUserProfile(input);
      await loadDetail(input.userId);
      return { success: true, message: '用户信息已更新。' };
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
      return { success: true, message: '已保存到后端。' };
    } catch (saveError) {
      return { success: false, message: getActionErrorMessage(saveError) };
    }
  };

  if (loading) {
    return (
      <div className="rounded-4xl border border-slate-200 bg-white/85 px-6 py-16 text-center text-sm text-slate-500 shadow-panel">
        正在加载用户详情…
      </div>
    );
  }

  if (!detail || error) {
    return (
      <div className="rounded-4xl border border-rose-100 bg-rose-50/70 px-6 py-16 text-center shadow-panel">
        <p className="text-sm text-rose-600">{error ?? '未找到用户详情。'}</p>
        <Link
          href="/users"
          className="mt-4 inline-flex h-11 items-center justify-center rounded-full bg-white px-5 text-sm font-semibold text-rose-600 ring-1 ring-rose-200 transition hover:bg-rose-50"
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
            <h1 className="mt-3 text-3xl font-semibold text-ink">{displayName}</h1>
            <p className="mt-2 font-mono text-sm text-slate-500">{detail.user.user_id}</p>
          </div>
          <div className="flex flex-wrap gap-3">
            <Link
              scroll={false}
              href={buildUserRouteHref('/users/detail', detail.user.user_id, selectedToolId)}
              className="inline-flex h-11 items-center justify-center rounded-full border border-slate-200 bg-white px-5 text-sm font-semibold text-slate-700 transition hover:border-brand-200 hover:bg-brand-50"
            >
              结构化管理
            </Link>
            <Link
              scroll={false}
              href={buildUserRouteHref('/users/json', detail.user.user_id, selectedToolId)}
              className="inline-flex h-11 items-center justify-center rounded-full bg-ink px-5 text-sm font-semibold text-white transition hover:bg-slate-800"
            >
              JSON 管理
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
            <p className="text-xs text-slate-400">最近同步行为</p>
            <p className="mt-1 font-medium text-ink">{formatSyncDecisionLabel(detail.recent_records[0]?.decision ?? '暂无')}</p>
          </div>
        </div>
      </section>

      <UserProfileEditor user={detail.user} saveUserAction={saveUserAction} />

      <section className="grid gap-6 xl:grid-cols-[320px_1fr]">
        <aside className="space-y-6">
          <div className="rounded-4xl border border-slate-200/80 bg-white/85 p-5 shadow-panel">
            <h2 className="text-lg font-semibold text-ink">同步工具</h2>
            <div className="mt-4 space-y-3">
              {detail.snapshot.tool_ids.map((toolId) => {
                const isActive = toolId === selectedToolId;
                const toolConfig = getToolConfig(toolId);
                const summary = detail.snapshot.tool_summaries.find((item) => item.tool_id === toolId);
                const topSections = Object.entries(summary?.section_counts ?? {})
                  .sort((left, right) => right[1] - left[1])
                  .slice(0, 2);
                return (
                  <Link
                    key={toolId}
                    scroll={false}
                    href={buildUserRouteHref('/users/detail', detail.user.user_id, toolId)}
                    className={`block rounded-3xl border px-4 py-4 transition ${
                      isActive
                        ? 'border-brand-300 bg-brand-50 text-brand-900'
                        : 'border-slate-200 bg-slate-50 text-slate-700 hover:border-brand-200 hover:bg-brand-50/60'
                    }`}
                  >
                    <p className="text-sm font-semibold">{toolConfig.name}</p>
                    <p className="mt-1 text-xs text-slate-500">{summary?.total_items ?? 0} 条记录 · {summary?.version ?? 0} 版</p>
                    {topSections.length > 0 ? (
                      <div className="mt-3 flex flex-wrap gap-2">
                        {topSections.map(([sectionKey, count]) => (
                          <span key={`${toolId}-${sectionKey}`} className="rounded-full bg-white/80 px-2.5 py-1 text-xs text-slate-600 ring-1 ring-slate-200">
                            {getToolConfig(toolId).sections.find((item) => item.key === sectionKey)?.label ?? sectionKey} {count}
                          </span>
                        ))}
                      </div>
                    ) : null}
                  </Link>
                );
              })}
              {detail.snapshot.tool_ids.length === 0 ? (
                <div className="rounded-3xl border border-dashed border-slate-200 bg-slate-50 px-4 py-10 text-center text-sm text-slate-500">
                  当前用户还没有同步工具数据，可先在移动端完成一次同步。
                </div>
              ) : null}
            </div>
          </div>

          {selectedToolSummary ? (
            <div className="rounded-4xl border border-slate-200/80 bg-white/85 p-5 shadow-panel">
              <h2 className="text-lg font-semibold text-ink">当前工具概览</h2>
              <div className="mt-4 space-y-3">
                {Object.entries(selectedToolSummary.section_counts).map(([sectionKey, count]) => (
                  <div key={sectionKey} className="flex items-center justify-between rounded-3xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
                    <span>{getToolConfig(selectedToolId ?? '').sections.find((item) => item.key === sectionKey)?.label ?? sectionKey}</span>
                    <span className="font-mono font-semibold text-ink">{count}</span>
                  </div>
                ))}
              </div>
            </div>
          ) : null}
        </aside>

        <div className="space-y-6">
          {selectedTool && relationContext ? (
            <ToolWorkspace
              userId={detail.user.user_id}
              tool={selectedTool}
              relationContext={relationContext}
              saveToolAction={saveToolAction}
            />
          ) : (
            <div className="rounded-4xl border border-dashed border-slate-200 bg-slate-50 px-6 py-16 text-center text-sm text-slate-500">
              当前用户暂无可管理的工具数据。
            </div>
          )}

          <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
            <h2 className="text-xl font-semibold text-ink">最近同步记录</h2>
            <div className="mt-5 divide-y divide-slate-100">
              {detail.recent_records.slice(0, 8).map((record) => (
                <div key={record.id} className="flex flex-col gap-2 py-4 md:flex-row md:items-center md:justify-between">
                  <div>
                    <p className="text-sm font-semibold text-ink">{formatSyncDecisionLabel(record.decision)}</p>
                    <p className="mt-1 text-xs text-slate-500">版本 {record.server_revision_before} → {record.server_revision_after}</p>
                  </div>
                  <div className="text-sm text-slate-500">{formatTimestamp(record.server_time)}</div>
                </div>
              ))}
              {detail.recent_records.length === 0 ? <p className="py-8 text-sm text-slate-500">暂无同步记录。</p> : null}
            </div>
          </section>
        </div>
      </section>
    </div>
  );
}
