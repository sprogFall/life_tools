'use client';

import { useEffect, useState } from 'react';

import { CreateUserForm } from '@/components/create-user-form';
import { UserDirectory } from '@/components/user-directory';
import { createDashboardUser, fetchDashboardUsers } from '@/lib/api';
import { getActionErrorMessage } from '@/lib/error-utils';
import type { CreateDashboardUserInput, DashboardActionResult, DashboardUserSummary } from '@/lib/types';

export function UsersScreen() {
  const [users, setUsers] = useState<DashboardUserSummary[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const loadUsers = async () => {
    setLoading(true);
    try {
      const nextUsers = await fetchDashboardUsers();
      setUsers(nextUsers);
      setError(null);
    } catch (loadError) {
      setError(getActionErrorMessage(loadError));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadUsers();
  }, []);

  const createUserAction = async (
    input: CreateDashboardUserInput,
  ): Promise<DashboardActionResult> => {
    try {
      await createDashboardUser(input);
      void loadUsers();
      return { success: true, message: '同步用户已创建。' };
    } catch (createError) {
      return { success: false, message: getActionErrorMessage(createError) };
    }
  };

  return (
    <div className="space-y-6">
      <section className="flex flex-col gap-3 rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel lg:flex-row lg:items-end lg:justify-between">
        <div>
          <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Sync Users</p>
          <h1 className="mt-2 text-3xl font-semibold text-ink">同步用户目录</h1>
          <p className="mt-2 text-sm text-slate-600">所有数据管理都以同步设置中的 user_id 为维度。你可以先创建管理档案，再让移动端按该 user_id 同步。</p>
        </div>
        <p className="rounded-full bg-brand-50 px-4 py-2 text-sm font-medium text-brand-800">
          当前共 {users.length} 个用户
        </p>
      </section>

      <div className="grid gap-6 xl:grid-cols-[380px_1fr]">
        <CreateUserForm createUserAction={createUserAction} />
        <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
          <h2 className="text-xl font-semibold text-ink">用户列表</h2>
          <p className="mt-1 text-sm text-slate-600">进入单个用户后，可以继续维护工作记录、库存、标签和原始 JSON。</p>
          <div className="mt-6">
            {loading ? (
              <div className="rounded-3xl border border-slate-200 bg-slate-50 px-4 py-10 text-center text-sm text-slate-500">
                正在加载用户列表…
              </div>
            ) : error ? (
              <div className="rounded-3xl border border-rose-100 bg-rose-50/70 px-4 py-10 text-center text-sm text-rose-600">
                <p>{error}</p>
                <button
                  type="button"
                  onClick={() => void loadUsers()}
                  className="mt-4 inline-flex h-10 items-center justify-center rounded-full bg-white px-4 text-sm font-semibold text-rose-600 ring-1 ring-rose-200 transition hover:bg-rose-50"
                >
                  重试加载
                </button>
              </div>
            ) : (
              <UserDirectory users={users} />
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
