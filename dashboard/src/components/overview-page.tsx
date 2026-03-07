import { buildOverviewStats } from '@/lib/dashboard-data';
import { getToolDisplayText } from '@/lib/tool-display';
import type { DashboardUserSummary } from '@/lib/types';
import { StatCard } from '@/components/stat-card';
import { UserDirectory } from '@/components/user-directory';

interface OverviewPageProps {
  users: DashboardUserSummary[];
}

export function OverviewPage({ users }: OverviewPageProps) {
  const stats = buildOverviewStats(users);
  const busiestUsers = [...users]
    .sort((left, right) => right.snapshot.total_item_count - left.snapshot.total_item_count)
    .slice(0, 3);

  return (
    <div className="space-y-8">
      <section className="rounded-[2rem] border border-brand-100/70 bg-gradient-to-br from-brand-900 via-brand-700 to-brand-500 p-8 text-white shadow-panel">
        <p className="text-sm uppercase tracking-[0.32em] text-white/70">Life Tools Dashboard</p>
        <div className="mt-4 flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div className="max-w-3xl">
            <h1 className="text-4xl font-semibold leading-tight">按同步用户维度统一管理工作记录、工具数据与同步状态</h1>
            <p className="mt-4 text-base leading-7 text-white/80">
              管理台直接连接 `backend/sync_server`，支持查看快照、维护用户资料，并对各工具数据做结构化编辑与保存。
            </p>
          </div>
          <a
            href="/users"
            className="inline-flex h-12 items-center justify-center rounded-full bg-white px-6 text-sm font-semibold text-brand-900 transition hover:bg-brand-50"
          >
            进入同步用户目录
          </a>
        </div>
      </section>

      <section className="grid gap-4 lg:grid-cols-5">
        <StatCard label="同步用户" value={stats.totalUsers} hint="已纳入管理台的用户总数" />
        <StatCard label="启用用户" value={stats.enabledUsers} hint="当前允许继续同步的用户" />
        <StatCard label="活跃用户" value={stats.activeUsers} hint="已有快照或近期触达的用户" />
        <StatCard label="同步工具" value={stats.syncedTools} hint="所有用户当前同步中的工具数" />
        <StatCard label="管理记录" value={stats.managedRecords} hint="按快照顶层列表估算的记录总量" />
      </section>

      <section className="grid gap-4 xl:grid-cols-[1.7fr_1fr]">
        <div className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
          <div className="flex items-center justify-between gap-3">
            <div>
              <h2 className="text-xl font-semibold text-ink">同步用户总览</h2>
              <p className="mt-1 text-sm text-slate-600">支持直接进入用户详情页，继续做工作记录、库存与标签管理。</p>
            </div>
            <a href="/users" className="text-sm font-medium text-brand-700 transition hover:text-brand-900">
              查看全部
            </a>
          </div>
          <div className="mt-6">
            <UserDirectory users={users.slice(0, 4)} />
          </div>
        </div>

        <aside className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
          <h2 className="text-xl font-semibold text-ink">高数据量用户</h2>
          <div className="mt-5 space-y-4">
            {busiestUsers.map((user) => (
              <a
                key={user.user_id}
                href={`/users/detail?userId=${encodeURIComponent(user.user_id)}`}
                className="block rounded-3xl border border-slate-100 bg-slate-50/80 p-4 transition hover:border-brand-200 hover:bg-brand-50/50"
              >
                <div className="flex items-center justify-between gap-3">
                  <div>
                    <p className="text-sm font-semibold text-ink">{user.display_name.trim() || user.user_id}</p>
                    <p className="mt-1 text-xs text-slate-500">{user.snapshot.tool_ids.map(getToolDisplayText).join(' · ') || '暂无工具'}</p>
                  </div>
                  <span className="font-mono text-sm font-semibold text-brand-800">{user.snapshot.total_item_count}</span>
                </div>
              </a>
            ))}
          </div>
        </aside>
      </section>
    </div>
  );
}
