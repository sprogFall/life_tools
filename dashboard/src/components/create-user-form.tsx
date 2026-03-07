'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';

import type { CreateDashboardUserInput, DashboardActionResult } from '@/lib/types';

interface CreateUserFormProps {
  createUserAction: (input: CreateDashboardUserInput) => Promise<DashboardActionResult>;
}

export function CreateUserForm({ createUserAction }: CreateUserFormProps) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [form, setForm] = useState({
    userId: '',
    displayName: '',
    notes: '',
    isEnabled: true,
  });
  const [message, setMessage] = useState<DashboardActionResult | null>(null);

  const submit = () => {
    startTransition(async () => {
      const result = await createUserAction(form);
      setMessage(result);
      if (result.success && form.userId.trim()) {
        router.push(`/users/detail?userId=${encodeURIComponent(form.userId.trim())}`);
      }
    });
  };

  return (
    <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
      <div>
        <h2 className="text-xl font-semibold text-ink">新增同步用户</h2>
        <p className="mt-1 text-sm text-slate-600">为尚未同步过的用户先创建管理档案，后续移动端即可按该 user_id 进行同步。</p>
      </div>
      <div className="mt-5 grid gap-4 md:grid-cols-2">
        <label className="space-y-2 text-sm text-slate-700">
          <span className="font-medium">用户 ID</span>
          <input
            value={form.userId}
            onChange={(event) => setForm((current) => ({ ...current, userId: event.target.value }))}
            className="h-12 w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 outline-none ring-0 transition focus:border-brand-400 focus:bg-white"
            placeholder="如：family_main"
          />
        </label>
        <label className="space-y-2 text-sm text-slate-700">
          <span className="font-medium">显示名称</span>
          <input
            value={form.displayName}
            onChange={(event) => setForm((current) => ({ ...current, displayName: event.target.value }))}
            className="h-12 w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 outline-none ring-0 transition focus:border-brand-400 focus:bg-white"
            placeholder="如：家庭共享账号"
          />
        </label>
        <label className="space-y-2 text-sm text-slate-700 md:col-span-2">
          <span className="font-medium">备注</span>
          <textarea
            value={form.notes}
            onChange={(event) => setForm((current) => ({ ...current, notes: event.target.value }))}
            className="min-h-28 w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 outline-none transition focus:border-brand-400 focus:bg-white"
            placeholder="可填写用途、设备归属、同步范围等说明"
          />
        </label>
      </div>
      <label className="mt-4 inline-flex items-center gap-3 text-sm text-slate-700">
        <input
          type="checkbox"
          checked={form.isEnabled}
          onChange={(event) => setForm((current) => ({ ...current, isEnabled: event.target.checked }))}
          className="h-4 w-4 rounded border-slate-300 text-brand-600"
        />
        <span>创建后立即启用</span>
      </label>
      {message ? (
        <p className={`mt-4 text-sm ${message.success ? 'text-emerald-700' : 'text-rose-600'}`}>{message.message}</p>
      ) : null}
      <button
        type="button"
        onClick={submit}
        disabled={isPending || form.userId.trim().length === 0}
        className="mt-5 inline-flex h-11 items-center justify-center rounded-full bg-brand-700 px-5 text-sm font-semibold text-white transition hover:bg-brand-800 disabled:cursor-not-allowed disabled:bg-slate-300"
      >
        {isPending ? '创建中...' : '创建同步用户'}
      </button>
    </section>
  );
}
