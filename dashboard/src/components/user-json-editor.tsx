'use client';

import { useEffect, useMemo, useState, useTransition } from 'react';

import { getToolDisplayText } from '@/lib/tool-display';
import {
  compactJsonErrorMessage,
  formatJsonText,
  parseDashboardToolSnapshotJson,
  parseDashboardToolsDataJson,
} from '@/lib/json-utils';
import type {
  DashboardActionResult,
  DashboardToolSnapshot,
  SaveDashboardSnapshotInput,
  SaveDashboardToolInput,
} from '@/lib/types';

interface UserJsonEditorProps {
  userId: string;
  toolsData: Record<string, DashboardToolSnapshot>;
  initialToolId?: string;
  saveSnapshotAction: (input: SaveDashboardSnapshotInput) => Promise<DashboardActionResult>;
  saveToolAction?: (input: SaveDashboardToolInput) => Promise<DashboardActionResult>;
}

const ALL_TOOLS_SCOPE = '__all_tools__';
const ACTIVE_SCOPE_BUTTON_CLASS = 'bg-brand-700 text-white shadow-sm';
const INACTIVE_SCOPE_BUTTON_CLASS =
  'border border-slate-200 bg-slate-50 text-slate-700 hover:border-brand-200 hover:bg-brand-50';

function resolveInitialScope(toolIds: string[], initialToolId?: string) {
  return initialToolId && toolIds.includes(initialToolId) ? initialToolId : ALL_TOOLS_SCOPE;
}

function getScopeButtonClass(isActive: boolean) {
  return `h-11 rounded-full px-4 text-sm font-medium transition ${
    isActive ? ACTIVE_SCOPE_BUTTON_CLASS : INACTIVE_SCOPE_BUTTON_CLASS
  }`;
}

export function UserJsonEditor({
  userId,
  toolsData,
  initialToolId,
  saveSnapshotAction,
  saveToolAction,
}: UserJsonEditorProps) {
  const toolIds = useMemo(() => Object.keys(toolsData), [toolsData]);
  const normalizedInitialScope = useMemo(
    () => resolveInitialScope(toolIds, initialToolId),
    [initialToolId, toolIds],
  );

  const [selectedScope, setSelectedScope] = useState<string>(normalizedInitialScope);
  const [editorText, setEditorText] = useState('');
  const [result, setResult] = useState<DashboardActionResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isPending, startTransition] = useTransition();

  useEffect(() => {
    setSelectedScope((current) => {
      if (current !== ALL_TOOLS_SCOPE && toolIds.includes(current)) {
        return current;
      }
      return normalizedInitialScope;
    });
  }, [normalizedInitialScope, toolIds]);

  const selectedToolId = selectedScope === ALL_TOOLS_SCOPE ? null : selectedScope;
  const selectedToolSnapshot = selectedToolId ? toolsData[selectedToolId] ?? null : null;
  const isSingleToolMode = selectedToolId !== null && selectedToolSnapshot !== null;

  const baselineText = useMemo(() => {
    if (isSingleToolMode) {
      return formatJsonText(selectedToolSnapshot);
    }
    return formatJsonText(toolsData);
  }, [isSingleToolMode, selectedToolSnapshot, toolsData]);

  useEffect(() => {
    setEditorText(baselineText);
    setResult(null);
    setError(null);
  }, [baselineText]);

  const dirty = editorText !== baselineText;
  const editorLabel = isSingleToolMode ? '当前工具 JSON' : '同步快照 JSON';
  const saveButtonText = isSingleToolMode ? '保存当前工具 JSON' : '保存 JSON 到后端';
  const titleText = isSingleToolMode ? `${getToolDisplayText(selectedToolId)} · JSON 管理` : '原始 JSON 管理';
  const descriptionText = isSingleToolMode
    ? '当前模式只编辑单个工具的 JSON 快照，保存时仅更新该工具，适合精确修复某个工具的数据。'
    : '这里直接编辑当前用户的同步快照 `tools_data`。保存时会先做结构校验，并以紧凑 JSON 发给后端；错误信息保持单行，避免占满页面。';

  const reset = () => {
    setEditorText(baselineText);
    setResult(null);
    setError(null);
  };

  const save = () => {
    startTransition(async () => {
      try {
        if (isSingleToolMode && selectedToolId && selectedToolSnapshot && saveToolAction) {
          const parsed = parseDashboardToolSnapshotJson(editorText, selectedToolId);
          const actionResult = await saveToolAction({
            userId,
            toolId: selectedToolId,
            version: parsed.version,
            data: parsed.data,
          });
          setResult(actionResult);
          setError(null);
          if (actionResult.success) {
            setEditorText(formatJsonText(parsed));
          }
          return;
        }

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
          <h2 className="mt-2 text-2xl font-semibold text-ink">{titleText}</h2>
          <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-600">{descriptionText}</p>
        </div>
        <div className="rounded-3xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
          <p>仅开放同步工具快照，用户档案与同步记录不在此处修改。</p>
          <p className="mt-1">结构化页面会限制敏感字段；此处属于高级模式，请谨慎操作。</p>
        </div>
      </div>

      <div className="mt-6 space-y-3">
        <p className="text-sm font-medium text-slate-700">编辑范围</p>
        <div className="flex flex-wrap gap-3">
          <button
            type="button"
            onClick={() => setSelectedScope(ALL_TOOLS_SCOPE)}
            className={getScopeButtonClass(selectedScope === ALL_TOOLS_SCOPE)}
          >
            全部快照
          </button>
          {toolIds.map((toolId) => (
            <button
              key={toolId}
              type="button"
              onClick={() => setSelectedScope(toolId)}
              className={getScopeButtonClass(selectedScope === toolId)}
            >
              {getToolDisplayText(toolId)}
            </button>
          ))}
        </div>
      </div>

      <label className="mt-6 block space-y-2 text-sm text-slate-700">
        <span className="font-medium">{editorLabel}</span>
        <textarea
          aria-label={editorLabel}
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
          {isPending ? '保存中...' : saveButtonText}
        </button>
      </div>
    </section>
  );
}
