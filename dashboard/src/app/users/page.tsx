import { CreateUserForm } from '@/components/create-user-form';
import { UserDirectory } from '@/components/user-directory';
import { createDashboardUserAction } from '@/lib/actions';
import { fetchDashboardUsers } from '@/lib/api';

export default async function UsersPage() {
  const users = await fetchDashboardUsers();

  return (
    <div className="space-y-6">
      <section className="flex flex-col gap-3 rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel lg:flex-row lg:items-end lg:justify-between">
        <div>
          <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Sync Users</p>
          <h1 className="mt-2 text-3xl font-semibold text-ink">同步用户目录</h1>
          <p className="mt-2 text-sm text-slate-600">所有数据管理都以同步设置中的 user_id 为维度。你可以先创建管理档案，再让移动端按该 user_id 同步。</p>
        </div>
        <p className="rounded-full bg-brand-50 px-4 py-2 text-sm font-medium text-brand-800">当前共 {users.length} 个用户</p>
      </section>

      <div className="grid gap-6 xl:grid-cols-[380px_1fr]">
        <CreateUserForm createUserAction={createDashboardUserAction} />
        <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
          <h2 className="text-xl font-semibold text-ink">用户列表</h2>
          <p className="mt-1 text-sm text-slate-600">进入单个用户后，可以继续维护工作记录、囤货助手、标签与其他同步工具的数据。</p>
          <div className="mt-6">
            <UserDirectory users={users} />
          </div>
        </section>
      </div>
    </div>
  );
}
