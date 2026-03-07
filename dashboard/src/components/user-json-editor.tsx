'use client';

import { useEffect, useMemo, useState, useTransition } from 'react';

import { compactJsonErrorMessage, formatJsonText, parseDashboardToolsDataJson } from '@/lib/json-utils';
import type {
  DashboardActionResult,
  DashboardToolSnapshot,
  SaveDashboardSnapshotInput,
} from '@/lib/types';

interface UserJsonEditorProps {
  userId: string;
  toolsData: Record<string, DashboardToolSnapshot>;
  saveSnapshotAction: (input: SaveDashboardSnapshotInput) => Promise<DashboardActionResult>;
}

export function UserJsonEditor({ userId, toolsData, saveSnapshotAction }: UserJsonEditorProps) {
  const baselineText = useMemo(() => formatJsonText(toolsData), [toolsData]);
  const [editorText, setEditorText] = useState(baselineText);
  const [result, setResult] = useState<DashboardActionResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  useEffect(() => {
    setEditorText(baselineText);
    setResult(null);
    setError(null);
  }, [baselineText]);

  const dirty = editorText !== baselineText;

  const reset = () => {
    setEditorText(baselineText);
    setResult(null);
    setError(null);
  };

  const save = () => {
    startTransition(async () => {
      try {
        const parsed = parseDashboardToolsDataJson(editorText);
        const actionResult = await saveSnapshotAction({
          userId,
          toolsData: parsed,
        });
        setResult(actionResult);
        setError(null);
        if (actionResult.success) {
          setEditorText(formatJsonText(parsed));
        }
      } catch (saveError) {
        setResult(null);
        setError(
          saveError instanceof Error
            ? saveError.message
            : compactJsonErrorMessage(saveError, 'JSON 保存失败'),
        );
      }
    });
  };

  return (
    <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <p className="text-xs uppercase tracking-[0.24em] text-slate-400">Advanced JSON</p>
          <h2 className="mt-2 text-2xl font-semibold text-ink">原始 JSON 管理</h2>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-600">
            这里直接编辑当前用户的同步快照 `tools_data`。保存时会先做结构校验，并以紧凑 JSON 发给后端；错误信息保持单行，避免占满页面。
          </p>
        </div>
        <div className="rounded-3xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
          <p>仅开放同步工具快照，用户档案与同步记录不在此处修改。</p>
          <p className="mt-1">结构化页面会限制敏感字段；此处属于高级模式，请谨慎操作。</p>
        </div>
      </div>

      <label className="mt-6 block space-y-2 text-sm text-slate-700">
        <span className="font-medium">同步快照 JSON</span>
        <textarea
          aria-label="同步快照 JSON"
          value={editorText}
          onChange={(event) => {
            setEditorText(event.target.value);
            if (error) {
              setError(null);
            }
          }}
          className="min-h-[520px] w-full rounded-3xl border border-slate-200 bg-slate-50 px-4 py-4 font-mono text-sm leading-6 outline-none transition focus:border-brand-400 focus:bg-white"
          spellCheck={false}
        />
      </label>

      {error ? (
        <p role="alert" className="mt-4 rounded-2xl bg-rose-50 px-4 py-3 text-sm text-rose-600">
          {error}
        </p>
      ) : null}
      {result ? (
        <p className={`mt-4 text-sm ${result.success ? 'text-emerald-700' : 'text-rose-600'}`}>
          {result.message}
        </p>
      ) : null}

      <div className="mt-5 flex flex-wrap gap-3">
        <button
          type="button"
          onClick={reset}
          disabled={!dirty || isPending}
          className="h-11 rounded-full border border-slate-200 bg-white px-5 text-sm font-semibold text-slate-700 transition hover:border-brand-200 hover:bg-brand-50 disabled:cursor-not-allowed disabled:opacity-50"
        >
          重置 JSON 草稿
        </button>
        <button
          type="button"
          onClick={save}
          disabled={!dirty || isPending}
          className="h-11 rounded-full bg-ink px-5 text-sm font-semibold text-white transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:bg-slate-300"
        >
          {isPending ? '保存中...' : '保存 JSON 到后端'}
        </button>
      </div>
    </section>
  );
}
