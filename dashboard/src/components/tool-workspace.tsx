'use client';

import { useEffect, useMemo, useState, useTransition } from 'react';

import { cn, formatNumber, formatTimestamp, truncateJsonPreview } from '@/lib/format';
import { getSectionConfig, getToolConfig, type ToolFieldConfig, type ToolSectionConfig } from '@/lib/tool-config';
import {
  buildRelationContext,
  coerceEditorValue,
  formatFriendlyValue,
  resolveFieldEditorMeta,
  type DashboardRelationContext,
} from '@/lib/tool-relations';
import type { DashboardActionResult, DashboardToolPayload, SaveDashboardToolInput } from '@/lib/types';

interface ToolWorkspaceProps {
  userId: string;
  tool: DashboardToolPayload;
  relationContext?: DashboardRelationContext;
  saveToolAction: (input: SaveDashboardToolInput) => Promise<DashboardActionResult>;
}

type EditableRow = Record<string, unknown>;

type EditorKey = number | 'new' | null;

const emptyRelationContext = buildRelationContext({
  success: true,
  user: {
    user_id: '',
    display_name: '',
    notes: '',
    is_enabled: true,
    created_at_ms: 0,
    updated_at_ms: 0,
    last_seen_at_ms: null,
    snapshot: {
      has_snapshot: false,
      server_revision: 0,
      updated_at_ms: 0,
      tool_count: 0,
      tool_ids: [],
      total_item_count: 0,
      tool_summaries: [],
    },
  },
  snapshot: {
    has_snapshot: false,
    server_revision: 0,
    updated_at_ms: 0,
    tool_count: 0,
    tool_ids: [],
    total_item_count: 0,
    tool_summaries: [],
    tools_data: {},
  },
  recent_records: [],
});

function cloneData<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T;
}

function isEditableRow(value: unknown): value is EditableRow {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function getSectionKeys(tool: DashboardToolPayload) {
  return Array.from(
    new Set([...Object.keys(tool.data), ...Object.keys(tool.summary.section_counts ?? {})]),
  );
}

function getSectionItems(data: Record<string, unknown>, sectionKey: string) {
  const raw = data[sectionKey];
  if (!Array.isArray(raw)) {
    return [] as EditableRow[];
  }
  return raw.filter(isEditableRow);
}

function toInputValue(field: ToolFieldConfig, value: unknown) {
  if (value === null || value === undefined) {
    return '';
  }
  if (field.type === 'json') {
    return JSON.stringify(value, null, 2);
  }
  if (field.type === 'date') {
    const date = new Date(Number(value));
    return Number.isNaN(date.getTime()) ? '' : date.toISOString().slice(0, 10);
  }
  if (field.type === 'datetime') {
    const date = new Date(Number(value));
    return Number.isNaN(date.getTime())
      ? ''
      : new Date(date.getTime() - date.getTimezoneOffset() * 60000)
          .toISOString()
          .slice(0, 16);
  }
  if (field.type === 'boolean') {
    return Boolean(value);
  }
  return String(value);
}

function fromInputValue(field: ToolFieldConfig, value: string | boolean) {
  if (field.type === 'boolean') {
    return Boolean(value);
  }
  if (typeof value !== 'string') {
    return value;
  }
  if (field.type === 'number') {
    return value.trim() === '' ? 0 : Number(value);
  }
  if (field.type === 'date') {
    return value ? new Date(`${value}T00:00:00`).getTime() : null;
  }
  if (field.type === 'datetime') {
    return value ? new Date(value).getTime() : null;
  }
  if (field.type === 'json') {
    return value.trim() ? JSON.parse(value) : [];
  }
  return value;
}

function inferFields(row: EditableRow): ToolFieldConfig[] {
  return Object.keys(row).map((key) => {
    const value = row[key];
    if (typeof value === 'boolean') {
      return { key, label: key, type: 'boolean' };
    }
    if (typeof value === 'number') {
      return {
        key,
        label: key,
        type: key.endsWith('_at') || key.includes('date') ? 'datetime' : 'number',
      };
    }
    if (Array.isArray(value) || isEditableRow(value)) {
      return { key, label: key, type: 'json' };
    }
    return {
      key,
      label: key,
      type: typeof value === 'string' && value.length > 60 ? 'textarea' : 'text',
    };
  });
}

function getDefaultRow(section: ToolSectionConfig | undefined, items: EditableRow[]) {
  const result: EditableRow = {};
  if (section?.fields?.length) {
    for (const field of section.fields) {
      if (field.type === 'boolean') {
        result[field.key] = false;
      } else if (field.type === 'number') {
        result[field.key] = 0;
      } else if (field.type === 'json') {
        result[field.key] = [];
      } else {
        result[field.key] = '';
      }
    }
  }
  if (section?.idKey) {
    const maxId = items.reduce((current, item) => {
      const raw = item[section.idKey!];
      const value = typeof raw === 'number' ? raw : Number(raw ?? 0);
      return Number.isFinite(value) ? Math.max(current, value) : current;
    }, 0);
    result[section.idKey] = maxId + 1;
  }
  return result;
}

function getPreviewKeys(section: ToolSectionConfig | undefined, items: EditableRow[]) {
  if (section?.fields?.length) {
    return section.fields.slice(0, 4).map((item) => item.key);
  }
  const first = items[0];
  return first ? Object.keys(first).slice(0, 4) : [];
}

function normalizeSectionCount(tool: DashboardToolPayload, sectionKey: string) {
  return (
    tool.summary.section_counts[sectionKey] ?? getSectionItems(tool.data, sectionKey).length
  );
}

function getFieldByKey(section: ToolSectionConfig | undefined, fieldKey: string, items: EditableRow[]): ToolFieldConfig {
  const configuredField = section?.fields?.find((item) => item.key === fieldKey);
  if (configuredField) {
    return configuredField;
  }
  const sample = items[0];
  if (sample) {
    const inferredField = inferFields(sample).find((item) => item.key === fieldKey);
    if (inferredField) {
      return inferredField;
    }
  }
  return { key: fieldKey, label: fieldKey, type: 'text' as const };
}

interface SectionPanelProps {
  toolId: string;
  sectionKey: string;
  section: ToolSectionConfig | undefined;
  items: EditableRow[];
  relationContext: DashboardRelationContext;
  onChange: (items: EditableRow[]) => void;
}

function SectionPanel({
  toolId,
  sectionKey,
  section,
  items,
  relationContext,
  onChange,
}: SectionPanelProps) {
  const [query, setQuery] = useState('');
  const [editorKey, setEditorKey] = useState<EditorKey>(items.length > 0 ? 0 : null);
  const [draftRow, setDraftRow] = useState<EditableRow | null>(
    items.length > 0 ? cloneData(items[0]) : null,
  );
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (editorKey === 'new') {
      return;
    }
    if (editorKey === null) {
      setDraftRow(items[0] ? cloneData(items[0]) : null);
      setEditorKey(items[0] ? 0 : null);
      return;
    }
    if (!items[editorKey]) {
      setEditorKey(items[0] ? 0 : null);
      setDraftRow(items[0] ? cloneData(items[0]) : null);
      return;
    }
    setDraftRow(cloneData(items[editorKey]));
  }, [editorKey, items]);

  const filteredItems = useMemo(() => {
    if (!query.trim()) {
      return items.map((item, index) => ({ item, index }));
    }
    const keyword = query.trim().toLowerCase();
    return items
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => JSON.stringify(item).toLowerCase().includes(keyword));
  }, [items, query]);

  const previewKeys = useMemo(() => getPreviewKeys(section, items), [items, section]);
  const fields = useMemo(
    () =>
      draftRow
        ? section?.fields?.length
          ? section.fields
          : inferFields(draftRow)
        : section?.fields ?? [],
    [draftRow, section],
  );

  const startCreate = () => {
    const nextRow = getDefaultRow(section, items);
    setEditorKey('new');
    setDraftRow(nextRow);
    setError(null);
  };

  const startEdit = (index: number) => {
    setEditorKey(index);
    setDraftRow(cloneData(items[index]));
    setError(null);
  };

  const saveRow = () => {
    if (!draftRow) {
      return;
    }
    try {
      const nextDraft = cloneData(draftRow);
      if (editorKey === 'new') {
        onChange([...items, nextDraft]);
        setEditorKey(items.length);
      } else if (typeof editorKey === 'number') {
        onChange(items.map((item, index) => (index === editorKey ? nextDraft : item)));
      }
      setError(null);
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存当前记录失败');
    }
  };

  const removeCurrent = () => {
    if (typeof editorKey !== 'number') {
      return;
    }
    const nextItems = items.filter((_, index) => index !== editorKey);
    onChange(nextItems);
    setEditorKey(nextItems[0] ? 0 : null);
  };

  const duplicateCurrent = () => {
    if (!draftRow) {
      return;
    }
    const nextRow = cloneData(draftRow);
    if (section?.idKey) {
      const maxId = items.reduce((current, item) => {
        const raw = item[section.idKey!];
        const numeric = typeof raw === 'number' ? raw : Number(raw ?? 0);
        return Number.isFinite(numeric) ? Math.max(current, numeric) : current;
      }, 0);
      nextRow[section.idKey] = maxId + 1;
    }
    onChange([...items, nextRow]);
  };

  return (
    <div className="grid gap-5 xl:grid-cols-[1.3fr_1fr]">
      <section className="rounded-4xl border border-slate-200/70 bg-white/75 p-5 shadow-panel">
        <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div>
            <h3 className="text-lg font-semibold text-ink">{section?.label ?? sectionKey}</h3>
            <p className="mt-1 text-sm text-slate-600">
              {section?.description ?? '当前区块使用通用数据维护视图。'}
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            <input
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="搜索当前区块"
              className="h-10 rounded-full border border-slate-200 bg-slate-50 px-4 text-sm outline-none transition focus:border-brand-400 focus:bg-white"
            />
            {!section?.readOnly ? (
              <button
                type="button"
                onClick={startCreate}
                className="h-10 rounded-full bg-brand-700 px-4 text-sm font-medium text-white transition hover:bg-brand-800"
              >
                新增记录
              </button>
            ) : null}
          </div>
        </div>
        <div className="mt-5 overflow-hidden rounded-3xl border border-slate-100">
          <div className="hidden grid-cols-[96px_repeat(4,minmax(0,1fr))] gap-3 bg-slate-50 px-4 py-3 text-xs font-medium uppercase tracking-[0.24em] text-slate-400 lg:grid">
            <span>操作</span>
            {previewKeys.map((key) => (
              <span key={key}>{getFieldByKey(section, key, items).label}</span>
            ))}
          </div>
          <div className="divide-y divide-slate-100">
            {filteredItems.length === 0 ? (
              <div className="px-4 py-10 text-center text-sm text-slate-500">
                暂无匹配结果，可尝试新增或调整筛选词。
              </div>
            ) : (
              filteredItems.map(({ item, index }) => {
                const isSelected = editorKey === index;
                return (
                  <button
                    key={`${sectionKey}-${index}`}
                    type="button"
                    onClick={() => startEdit(index)}
                    className={cn(
                      'grid w-full gap-3 px-4 py-4 text-left transition lg:grid-cols-[96px_repeat(4,minmax(0,1fr))]',
                      isSelected ? 'bg-brand-50/70' : 'bg-white hover:bg-slate-50',
                    )}
                  >
                    <span className="text-xs font-medium text-brand-700">编辑记录</span>
                    {previewKeys.map((key) => {
                      const rawText = truncateJsonPreview(item[key]);
                      const friendlyText = truncateJsonPreview(
                        formatFriendlyValue({
                          toolId,
                          sectionKey,
                          fieldKey: key,
                          value: item[key],
                          row: item,
                          context: relationContext,
                        }),
                      );
                      return (
                        <span key={key} className="flex flex-col gap-1 text-sm text-slate-600">
                          <span className="font-medium text-ink">{friendlyText}</span>
                          {friendlyText !== rawText ? (
                            <span className="text-xs text-slate-400">原始值：{rawText}</span>
                          ) : null}
                        </span>
                      );
                    })}
                  </button>
                );
              })
            )}
          </div>
        </div>
      </section>

      <section className="rounded-4xl border border-slate-200/70 bg-white/75 p-5 shadow-panel">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h3 className="text-lg font-semibold text-ink">记录编辑器</h3>
            <p className="mt-1 text-sm text-slate-600">
              修改当前区块的单条记录，最后统一点击顶部“保存到后端”。
            </p>
          </div>
          {section?.readOnly ? (
            <span className="rounded-full bg-slate-100 px-3 py-1 text-xs text-slate-500">只读</span>
          ) : null}
        </div>
        {draftRow ? (
          <div className="mt-5 space-y-4">
            {fields.map((field) => {
              const value = draftRow[field.key];
              const editorMeta = resolveFieldEditorMeta({
                toolId,
                sectionKey,
                fieldKey: field.key,
                value,
                row: draftRow,
                context: relationContext,
              });
              const friendlyText = formatFriendlyValue({
                toolId,
                sectionKey,
                fieldKey: field.key,
                value,
                row: draftRow,
                context: relationContext,
              });

              if (field.type === 'boolean') {
                return (
                  <label
                    key={field.key}
                    className="flex items-center gap-3 rounded-3xl bg-slate-50 px-4 py-3 text-sm text-slate-700"
                  >
                    <input
                      type="checkbox"
                      checked={Boolean(value)}
                      disabled={section?.readOnly}
                      onChange={(event) =>
                        setDraftRow((current) => ({
                          ...(current ?? {}),
                          [field.key]: event.target.checked,
                        }))
                      }
                    />
                    <span>{field.label}</span>
                  </label>
                );
              }

              if (editorMeta.kind === 'select') {
                return (
                  <label key={field.key} className="block space-y-2 text-sm text-slate-700">
                    <span className="font-medium">{field.label}</span>
                    <select
                      aria-label={field.label}
                      value={value === null || value === undefined ? '' : String(value)}
                      disabled={section?.readOnly}
                      onChange={(event) =>
                        setDraftRow((current) => ({
                          ...(current ?? {}),
                          [field.key]: coerceEditorValue(editorMeta, event.target.value),
                        }))
                      }
                      className="h-12 w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 outline-none transition focus:border-brand-400 focus:bg-white"
                    >
                      <option value="">请选择</option>
                      {editorMeta.options.map((option) => (
                        <option key={`${field.key}-${option.value}`} value={String(option.value)}>
                          {option.label}
                        </option>
                      ))}
                    </select>
                    <p className="text-xs text-slate-500">当前展示：{friendlyText}</p>
                  </label>
                );
              }

              if (field.type === 'textarea' || field.type === 'json') {
                return (
                  <label key={field.key} className="block space-y-2 text-sm text-slate-700">
                    <span className="font-medium">{field.label}</span>
                    <textarea
                      aria-label={field.label}
                      value={String(toInputValue(field, value))}
                      disabled={section?.readOnly}
                      onChange={(event) => {
                        setDraftRow((current) => {
                          try {
                            return {
                              ...(current ?? {}),
                              [field.key]: fromInputValue(field, event.target.value),
                            };
                          } catch (parseError) {
                            setError(
                              parseError instanceof Error ? parseError.message : 'JSON 解析失败',
                            );
                            return current;
                          }
                        });
                      }}
                      className="min-h-28 w-full rounded-3xl border border-slate-200 bg-slate-50 px-4 py-3 font-mono text-sm outline-none transition focus:border-brand-400 focus:bg-white"
                    />
                    {field.type === 'json' ? (
                      <p className="text-xs text-slate-500">复杂结构仍保留 JSON 编辑，以避免误改关联关系。</p>
                    ) : null}
                  </label>
                );
              }

              return (
                <label key={field.key} className="block space-y-2 text-sm text-slate-700">
                  <span className="font-medium">{field.label}</span>
                  <input
                    aria-label={field.label}
                    type={
                      field.type === 'number'
                        ? 'number'
                        : field.type === 'date'
                          ? 'date'
                          : field.type === 'datetime'
                            ? 'datetime-local'
                            : 'text'
                    }
                    value={String(toInputValue(field, value))}
                    disabled={section?.readOnly}
                    onChange={(event) =>
                      setDraftRow((current) => ({
                        ...(current ?? {}),
                        [field.key]: fromInputValue(field, event.target.value),
                      }))
                    }
                    className="h-12 w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 outline-none transition focus:border-brand-400 focus:bg-white"
                  />
                  {friendlyText !== String(toInputValue(field, value) || '—') ? (
                    <p className="text-xs text-slate-500">当前展示：{friendlyText}</p>
                  ) : null}
                </label>
              );
            })}
            {error ? (
              <p role="alert" className="rounded-2xl bg-rose-50 px-4 py-3 text-sm text-rose-600">
                {error}
              </p>
            ) : null}
            <div className="flex flex-wrap gap-3">
              {!section?.readOnly ? (
                <>
                  <button
                    type="button"
                    onClick={saveRow}
                    className="h-11 rounded-full bg-brand-700 px-5 text-sm font-semibold text-white transition hover:bg-brand-800"
                  >
                    保存当前记录
                  </button>
                  <button
                    type="button"
                    onClick={duplicateCurrent}
                    className="h-11 rounded-full border border-slate-200 px-5 text-sm font-semibold text-slate-700 transition hover:border-brand-200 hover:bg-brand-50"
                  >
                    复制一条
                  </button>
                  <button
                    type="button"
                    onClick={removeCurrent}
                    disabled={typeof editorKey !== 'number'}
                    className="h-11 rounded-full border border-rose-200 px-5 text-sm font-semibold text-rose-600 transition hover:bg-rose-50 disabled:cursor-not-allowed disabled:border-slate-200 disabled:text-slate-400"
                  >
                    删除当前记录
                  </button>
                </>
              ) : null}
            </div>
          </div>
        ) : (
          <div className="mt-5 rounded-3xl border border-dashed border-slate-200 bg-slate-50 px-4 py-10 text-center text-sm text-slate-500">
            先从左侧选择一条记录，或新增一条空记录开始编辑。
          </div>
        )}
        <div className="mt-5 rounded-3xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
          <p>当前区块条数：{items.length}</p>
          <p className="mt-1">
            最近更新时间：{draftRow?.updated_at ? formatTimestamp(Number(draftRow.updated_at)) : '—'}
          </p>
          <p className="mt-1">工具：{getToolConfig(toolId).name}</p>
        </div>
      </section>
    </div>
  );
}

export function ToolWorkspace({
  userId,
  tool,
  relationContext = emptyRelationContext,
  saveToolAction,
}: ToolWorkspaceProps) {
  const toolConfig = getToolConfig(tool.tool_id);
  const [activeSection, setActiveSection] = useState<string | null>(null);
  const [baselineData, setBaselineData] = useState<Record<string, unknown>>(cloneData(tool.data));
  const [draftData, setDraftData] = useState<Record<string, unknown>>(cloneData(tool.data));
  const [result, setResult] = useState<DashboardActionResult | null>(null);
  const [isPending, startTransition] = useTransition();

  const sectionKeys = useMemo(() => getSectionKeys(tool), [tool]);

  useEffect(() => {
    const nextData = cloneData(tool.data);
    setBaselineData(nextData);
    setDraftData(nextData);
    setActiveSection((current) =>
      current && sectionKeys.includes(current) ? current : sectionKeys[0] ?? null,
    );
  }, [sectionKeys, tool]);

  const dirty = JSON.stringify(baselineData) !== JSON.stringify(draftData);
  const currentSection = activeSection ? getSectionConfig(tool.tool_id, activeSection) : undefined;

  const save = () => {
    startTransition(async () => {
      const actionResult = await saveToolAction({
        userId,
        toolId: tool.tool_id,
        version: tool.version,
        data: draftData,
      });
      setResult(actionResult);
      if (actionResult.success) {
        setBaselineData(cloneData(draftData));
      }
    });
  };

  const reset = () => {
    setDraftData(cloneData(baselineData));
    setResult(null);
  };

  return (
    <section className="space-y-5 rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
      <div className={`rounded-4xl bg-gradient-to-br ${toolConfig.accentClassName} p-6`}>
        <div className="flex flex-col gap-5 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="text-xs uppercase tracking-[0.24em] text-slate-500">Tool Workspace</p>
            <h2 className="mt-2 text-2xl font-semibold text-ink">{toolConfig.name}</h2>
            <p className="mt-2 max-w-2xl text-sm leading-6 text-slate-600">
              {toolConfig.description}
            </p>
            <p className="mt-3 text-sm font-medium text-slate-700">
              共管理 {formatNumber(tool.summary.total_items)} 条记录
            </p>
          </div>
          <div className="flex flex-wrap gap-3">
            <button
              type="button"
              onClick={reset}
              disabled={!dirty || isPending}
              className="h-11 rounded-full border border-slate-200 bg-white/80 px-5 text-sm font-semibold text-slate-700 transition hover:border-brand-200 hover:bg-white disabled:cursor-not-allowed disabled:opacity-50"
            >
              重置草稿
            </button>
            <button
              type="button"
              onClick={save}
              disabled={!dirty || isPending}
              className="h-11 rounded-full bg-ink px-5 text-sm font-semibold text-white transition hover:bg-slate-800 disabled:cursor-not-allowed disabled:bg-slate-300"
            >
              {isPending ? '保存中...' : '保存到后端'}
            </button>
          </div>
        </div>
        {result ? (
          <p className={`mt-4 text-sm ${result.success ? 'text-emerald-700' : 'text-rose-600'}`}>
            {result.message}
          </p>
        ) : null}
      </div>

      <div className="flex flex-wrap gap-3">
        {sectionKeys.map((sectionKey) => {
          const section = getSectionConfig(tool.tool_id, sectionKey);
          const count = normalizeSectionCount(tool, sectionKey);
          return (
            <button
              key={sectionKey}
              type="button"
              aria-label={`${sectionKey} (${count})`}
              onClick={() => setActiveSection(sectionKey)}
              className={cn(
                'h-11 rounded-full px-4 text-sm font-medium transition',
                activeSection === sectionKey
                  ? 'bg-brand-700 text-white shadow-sm'
                  : 'border border-slate-200 bg-slate-50 text-slate-700 hover:border-brand-200 hover:bg-brand-50',
              )}
            >
              {section?.label ?? sectionKey} ({count})
            </button>
          );
        })}
      </div>

      {activeSection ? (
        <SectionPanel
          toolId={tool.tool_id}
          sectionKey={activeSection}
          section={currentSection}
          items={getSectionItems(draftData, activeSection)}
          relationContext={relationContext}
          onChange={(items) => setDraftData((current) => ({ ...current, [activeSection]: items }))}
        />
      ) : (
        <div className="rounded-4xl border border-dashed border-slate-200 bg-slate-50 px-6 py-16 text-center text-sm text-slate-500">
          当前工具暂无可管理区块。
        </div>
      )}
    </section>
  );
}
