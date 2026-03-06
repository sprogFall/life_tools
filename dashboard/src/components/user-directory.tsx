import { formatNumber, formatTimestamp, getUserDisplayName } from '@/lib/format';
import type { DashboardUserSummary } from '@/lib/types';

interface UserDirectoryProps {
  users: DashboardUserSummary[];
}

export function UserDirectory({ users }: UserDirectoryProps) {
  return (
    <div className="grid gap-4 lg:grid-cols-2">
      {users.map((user) => {
        const displayName = getUserDisplayName(user);
        return (
          <a
            key={user.user_id}
            href={`/users/${encodeURIComponent(user.user_id)}`}
            className="group cursor-pointer rounded-4xl border border-slate-200/80 bg-white/85 p-5 shadow-panel transition hover:-translate-y-0.5 hover:border-brand-200 hover:shadow-2xl"
          >
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Sync User</p>
                <h3 className="mt-2 text-xl font-semibold text-ink">{displayName}</h3>
                {displayName !== user.user_id ? (
                  <p className="mt-1 font-mono text-xs text-slate-500">{user.user_id}</p>
                ) : null}
              </div>
              <span
                className={`rounded-full px-3 py-1 text-xs font-medium ${
                  user.is_enabled
                    ? 'bg-emerald-50 text-emerald-700 ring-1 ring-emerald-200'
                    : 'bg-slate-100 text-slate-600 ring-1 ring-slate-200'
                }`}
              >
                {user.is_enabled ? '已启用' : '已停用'}
              </span>
            </div>
            <p className="mt-4 line-clamp-2 min-h-10 text-sm text-slate-600">
              {user.notes.trim() || '暂无备注，进入详情页后可维护用户说明与使用场景。'}
            </p>
            <div className="mt-5 grid gap-3 sm:grid-cols-3">
              <div className="rounded-3xl bg-slate-50 p-3">
                <p className="text-xs text-slate-500">同步工具</p>
                <p className="mt-1 text-sm font-semibold text-ink">
                  {user.snapshot.has_snapshot
                    ? `同步工具 ${formatNumber(user.snapshot.tool_count)} 个`
                    : '暂无快照'}
                </p>
              </div>
              <div className="rounded-3xl bg-slate-50 p-3">
                <p className="text-xs text-slate-500">管理记录</p>
                <p className="mt-1 text-sm font-semibold text-ink">
                  {formatNumber(user.snapshot.total_item_count)} 条
                </p>
              </div>
              <div className="rounded-3xl bg-slate-50 p-3">
                <p className="text-xs text-slate-500">最近活动</p>
                <p className="mt-1 text-sm font-semibold text-ink">
                  {formatTimestamp(user.last_seen_at_ms ?? user.snapshot.updated_at_ms ?? null)}
                </p>
              </div>
            </div>
          </a>
        );
      })}
    </div>
  );
}
