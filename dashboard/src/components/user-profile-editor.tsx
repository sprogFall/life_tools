'use client';

import { useState, useTransition } from 'react';

import { formatTimestamp } from '@/lib/format';
import type { DashboardActionResult, DashboardUserSummary, SaveDashboardUserProfileInput } from '@/lib/types';

interface UserProfileEditorProps {
  user: DashboardUserSummary;
  saveUserAction: (input: SaveDashboardUserProfileInput) => Promise<DashboardActionResult>;
}

export function UserProfileEditor({ user, saveUserAction }: UserProfileEditorProps) {
  const [isPending, startTransition] = useTransition();
  const [form, setForm] = useState({
    displayName: user.display_name,
    notes: user.notes,
    isEnabled: user.is_enabled,
  });
  const [message, setMessage] = useState<DashboardActionResult | null>(null);

  const submit = () => {
    startTransition(async () => {
      const result = await saveUserAction({
        userId: user.user_id,
        displayName: form.displayName,
        notes: form.notes,
        isEnabled: form.isEnabled,
      });
      setMessage(result);
    });
  };

  return (
    <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
      <div className="flex flex-col gap-2 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Sync User</p>
          <h2 className="mt-2 text-2xl font-semibold text-ink">{user.display_name.trim() || user.user_id}</h2>
          <p className="mt-1 font-mono text-sm text-slate-500">{user.user_id}</p>
        </div>
        <div className="grid gap-3 rounded-3xl bg-slate-50 px-4 py-3 text-sm text-slate-600 sm:grid-cols-3">
          <div>
            <p className="text-xs text-slate-400">最近触达</p>
            <p className="mt-1 font-medium text-ink">{formatTimestamp(user.last_seen_at_ms)}</p>
          </div>
          <div>
            <p className="text-xs text-slate-400">当前版本</p>
            <p className="mt-1 font-medium text-ink">r{user.snapshot.server_revision}</p>
          </div>
          <div>
            <p className="text-xs text-slate-400">同步工具</p>
            <p className="mt-1 font-medium text-ink">{user.snapshot.tool_count} 个</p>
          </div>
        </div>
      </div>
      <div className="mt-6 grid gap-4 md:grid-cols-2">
        <label className="space-y-2 text-sm text-slate-700">
          <span className="font-medium">显示名称</span>
          <input
            value={form.displayName}
            onChange={(event) => setForm((current) => ({ ...current, displayName: event.target.value }))}
            className="h-12 w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 outline-none transition focus:border-brand-400 focus:bg-white"
          />
        </label>
        <label className="inline-flex items-end gap-3 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={form.isEnabled}
            onChange={(event) => setForm((current) => ({ ...current, isEnabled: event.target.checked }))}
            className="mb-1 h-4 w-4 rounded border-slate-300 text-brand-600"
          />
          <span>允许该用户继续同步</span>
        </label>
        <label className="space-y-2 text-sm text-slate-700 md:col-span-2">
          <span className="font-medium">管理备注</span>
          <textarea
            value={form.notes}
            onChange={(event) => setForm((current) => ({ ...current, notes: event.target.value }))}
            className="min-h-28 w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 py-3 outline-none transition focus:border-brand-400 focus:bg-white"
          />
        </label>
      </div>
      {message ? (
        <p className={`mt-4 text-sm ${message.success ? 'text-emerald-700' : 'text-rose-600'}`}>{message.message}</p>
      ) : null}
      <button
        type="button"
        onClick={submit}
        disabled={isPending}
        className="mt-5 inline-flex h-11 items-center justify-center rounded-full bg-ink px-5 text-sm font-semibold text-white transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:bg-slate-300"
      >
        {isPending ? '保存中...' : '保存用户设置'}
      </button>
    </section>
  );
}
