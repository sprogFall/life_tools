import { notFound } from 'next/navigation';

import { ToolWorkspace } from '@/components/tool-workspace';
import { UserProfileEditor } from '@/components/user-profile-editor';
import { buildToolPayload, resolveSelectedToolId } from '@/lib/dashboard-data';
import { saveDashboardToolAction, saveDashboardUserProfileAction } from '@/lib/actions';
import { fetchDashboardUserDetail } from '@/lib/api';
import { formatTimestamp, getUserDisplayName } from '@/lib/format';
import { getToolDisplayText } from '@/lib/tool-display';

interface UserDetailPageProps {
  params: Promise<{ userId: string }>;
  searchParams?: Promise<Record<string, string | string[] | undefined>>;
}

export default async function UserDetailPage({ params, searchParams }: UserDetailPageProps) {
  const { userId } = await params;
  const resolvedSearchParams = searchParams ? await searchParams : {};
  const detail = await fetchDashboardUserDetail(userId).catch(() => null);
  if (!detail) {
    notFound();
  }

  const selectedToolId = resolveSelectedToolId(
    typeof resolvedSearchParams.tool === 'string' ? resolvedSearchParams.tool : null,
    detail.snapshot.tool_ids,
  );
  const selectedTool = selectedToolId ? buildToolPayload(detail, selectedToolId) : null;
  const displayName = getUserDisplayName(detail.user);

  return (
    <div className="space-y-6">
      <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <a href="/users" className="text-sm font-medium text-brand-700 transition hover:text-brand-900">
              ← 返回同步用户目录
            </a>
            <h1 className="mt-3 text-3xl font-semibold text-ink">{displayName}</h1>
            <p className="mt-2 font-mono text-sm text-slate-500">{detail.user.user_id}</p>
          </div>
          <div className="grid gap-3 rounded-3xl bg-slate-50 px-4 py-3 text-sm text-slate-600 sm:grid-cols-3">
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
              <p className="mt-1 font-medium text-ink">{detail.recent_records[0]?.decision ?? '暂无'}</p>
            </div>
          </div>
        </div>
      </section>

      <UserProfileEditor user={detail.user} saveUserAction={saveDashboardUserProfileAction} />

      <section className="grid gap-6 xl:grid-cols-[300px_1fr]">
        <aside className="rounded-4xl border border-slate-200/80 bg-white/85 p-5 shadow-panel">
          <h2 className="text-lg font-semibold text-ink">同步工具</h2>
          <div className="mt-4 space-y-3">
            {detail.snapshot.tool_ids.map((toolId) => {
              const isActive = toolId === selectedToolId;
              return (
                <a
                  key={toolId}
                  href={`/users/${encodeURIComponent(detail.user.user_id)}?tool=${encodeURIComponent(toolId)}`}
                  className={`block rounded-3xl border px-4 py-4 transition ${
                    isActive
                      ? 'border-brand-300 bg-brand-50 text-brand-900'
                      : 'border-slate-200 bg-slate-50 text-slate-700 hover:border-brand-200 hover:bg-brand-50/60'
                  }`}
                >
                  <p className="text-sm font-semibold">{getToolDisplayText(toolId)}</p>
                  <p className="mt-1 text-xs text-slate-500">{detail.snapshot.tool_summaries.find((item) => item.tool_id === toolId)?.total_items ?? 0} 条记录</p>
                </a>
              );
            })}
            {detail.snapshot.tool_ids.length === 0 ? (
              <div className="rounded-3xl border border-dashed border-slate-200 bg-slate-50 px-4 py-10 text-center text-sm text-slate-500">
                当前用户还没有同步工具数据，可先在移动端完成一次同步。
              </div>
            ) : null}
          </div>
        </aside>

        <div className="space-y-6">
          {selectedTool ? (
            <ToolWorkspace userId={detail.user.user_id} tool={selectedTool} saveToolAction={saveDashboardToolAction} />
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
                    <p className="text-sm font-semibold text-ink">{record.decision}</p>
                    <p className="mt-1 text-xs text-slate-500">版本 {record.server_revision_before} → {record.server_revision_after}</p>
                  </div>
                  <div className="text-sm text-slate-500">{formatTimestamp(record.server_time)}</div>
                </div>
              ))}
              {detail.recent_records.length === 0 ? (
                <p className="py-8 text-sm text-slate-500">暂无同步记录。</p>
              ) : null}
            </div>
          </section>
        </div>
      </section>
    </div>
  );
}
