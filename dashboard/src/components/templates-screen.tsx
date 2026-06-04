'use client';

import { useEffect, useState } from 'react';
import { fetchDashboardUsers } from '@/lib/api';
import { getActionErrorMessage } from '@/lib/error-utils';
import type { DashboardUserSummary } from '@/lib/types';
import { TemplateManager } from './template-manager';

export function TemplatesScreen() {
  const [users, setUsers] = useState<DashboardUserSummary[]>([]);
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const loadUsers = async () => {
    setLoading(true);
    try {
      const nextUsers = await fetchDashboardUsers();
      setUsers(nextUsers);
      setError(null);
      // 默认选择第一个用户
      if (nextUsers.length > 0 && !selectedUserId) {
        setSelectedUserId(nextUsers[0].user_id);
      }
    } catch (loadError) {
      setError(getActionErrorMessage(loadError));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadUsers();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="space-y-6">
      <section className="flex flex-col gap-3 rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel lg:flex-row lg:items-end lg:justify-between">
        <div>
          <p className="text-xs font-semibold text-brand-700">树形配置工作台</p>
          <h1 className="mt-2 text-3xl font-semibold text-ink">外拍助手模板管理</h1>
          <p className="mt-2 text-sm text-slate-600">
            按模板维护目录层级、目录选项和拍摄项，所有配置会同步到移动端外拍助手使用。
          </p>
        </div>
      </section>

      {loading ? (
        <div className="rounded-4xl border border-slate-200/80 bg-white/85 p-10 text-center text-sm text-slate-500 shadow-panel">
          正在加载用户列表…
        </div>
      ) : error ? (
        <div className="rounded-4xl border border-rose-100 bg-rose-50/70 p-10 text-center text-sm text-rose-600 shadow-panel">
          <p>{error}</p>
          <button
            type="button"
            onClick={() => void loadUsers()}
            className="mt-4 inline-flex h-10 items-center justify-center rounded-full bg-white px-4 text-sm font-semibold text-rose-600 ring-1 ring-rose-200 transition hover:bg-rose-50"
          >
            重试加载
          </button>
        </div>
      ) : users.length === 0 ? (
        <div className="rounded-4xl border border-slate-200/80 bg-slate-50 p-10 text-center text-sm text-slate-500 shadow-panel">
          暂无用户，请先在用户目录中创建用户。
        </div>
      ) : (
        <div className="space-y-6">
          <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
            <label htmlFor="user-select" className="block text-sm font-medium text-slate-700">
              选择用户
            </label>
            <select
              id="user-select"
              value={selectedUserId || ''}
              onChange={(e) => setSelectedUserId(e.target.value)}
              className="mt-2 block w-full rounded-2xl border border-slate-200 bg-white px-4 py-2 text-sm text-slate-900 shadow-sm transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20"
            >
              {users.map((user) => (
                <option key={user.user_id} value={user.user_id}>
                  {user.display_name || user.user_id}
                </option>
              ))}
            </select>
          </section>

          {selectedUserId && <TemplateManager userId={selectedUserId} />}
        </div>
      )}
    </div>
  );
}
