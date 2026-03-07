'use client';

import { useEffect, useMemo, useState, useTransition } from 'react';

import { Eye, EyeOff } from 'lucide-react';

import { cn, formatNumber, formatPreviewText, formatTimestamp, truncateJsonPreview } from '@/lib/format';
import { compactJsonErrorMessage } from '@/lib/json-utils';
import {
  getSectionConfig,
  getToolConfig,
  type ToolFieldConfig,
  type ToolSectionConfig,
  type ToolSectionMode,
} from '@/lib/tool-config';
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

type SectionStorageMode = ToolSectionMode;
type MobilePane = 'list' | 'editor';

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

function resolveSectionMode(
  data: Record<string, unknown>,
  sectionKey: string,
  section?: ToolSectionConfig,
): SectionStorageMode {
  if (section?.mode) {
    return section.mode;
  }
  const raw = data[sectionKey];
  if (isEditableRow(raw)) {
    return 'single';
  }
  return 'list';
}

function getSectionItems(
  data: Record<string, unknown>,
  sectionKey: string,
  section?: ToolSectionConfig,
) {
  const raw = data[sectionKey];
  const mode = resolveSectionMode(data, sectionKey, section);
  if (mode === 'single') {
    return isEditableRow(raw) ? [raw] : ([] as EditableRow[]);
  }
  if (!Array.isArray(raw)) {
    return [] as EditableRow[];
  }
  return raw.filter(isEditableRow);
}

function writeSectionData(
  current: Record<string, unknown>,
  sectionKey: string,
  mode: SectionStorageMode,
  items: EditableRow[],
) {
  return {
    ...current,
    [sectionKey]: mode === 'single' ? (items[0] ?? null) : items,
  };
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

function fromInputValue(field: ToolFieldConfig, value: string | boolean, currentValue?: unknown) {
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
    if (!value.trim()) {
      if (field.defaultValue !== undefined) {
        return cloneData(field.defaultValue);
      }
      if (Array.isArray(currentValue)) {
        return [];
      }
      if (isEditableRow(currentValue)) {
        return {};
      }
      return [];
    }
    try {
      return JSON.parse(value);
    } catch {
      throw new Error(`${field.label ?? field.key} 的 JSON 格式不正确`);
    }
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
  const now = Date.now();
  if (section?.fields?.length) {
    for (const field of section.fields) {
      if (field.defaultValue !== undefined) {
        result[field.key] = cloneData(field.defaultValue);
      } else if (field.key === 'created_at' || field.key === 'updated_at') {
        result[field.key] = now;
      } else if (field.type === 'boolean') {
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
  const section = getSectionConfig(tool.tool_id, sectionKey);
  return tool.summary.section_counts[sectionKey] ?? getSectionItems(tool.data, sectionKey, section).length;
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

const AUTO_READONLY_FIELD_KEYS = new Set(['created_at', 'updated_at']);

function isSensitiveField(section: ToolSectionConfig | undefined, field: ToolFieldConfig) {
  return Boolean(field.readOnly) || section?.idKey === field.key || AUTO_READONLY_FIELD_KEYS.has(field.key);
}

function isMaskedField(field: ToolFieldConfig) {
  return Boolean(field.sensitive);
}

function getMaskedValue(value: unknown) {
  if (value === null || value === undefined || value === '') {
    return '';
  }
  const text = typeof value === 'string' ? value : JSON.stringify(value);
  const maskLength = Math.max(8, Math.min(16, text.length));
  return '•'.repeat(maskLength);
}

function getFieldReadOnlyHint(section: ToolSectionConfig | undefined, field: ToolFieldConfig) {
  if (!isSensitiveField(section, field)) {
    return null;
  }
  if (section?.idKey === field.key) {
    return '主键由系统维护，不能直接修改。';
  }
  if (AUTO_READONLY_FIELD_KEYS.has(field.key)) {
    return '系统时间字段由管理台自动维护。';
  }
  return '该字段已锁定，避免误改敏感信息。';
}

function prepareRowForSave(
  section: ToolSectionConfig | undefined,
  row: EditableRow,
  items: EditableRow[],
  options?: {
    forceNewIdentity?: boolean;
  },
) {
  const nextRow = cloneData(row);
  const now = Date.now();

  if (section?.idKey) {
    const shouldRegenerateId = options?.forceNewIdentity || nextRow[section.idKey] === '' || nextRow[section.idKey] === null || nextRow[section.idKey] === undefined;
    if (shouldRegenerateId) {
      const maxId = items.reduce((current, item) => {
        const raw = item[section.idKey!];
        const numeric = typeof raw === 'number' ? raw : Number(raw ?? 0);
        return Number.isFinite(numeric) ? Math.max(current, numeric) : current;
      }, 0);
      nextRow[section.idKey] = maxId + 1;
    }
  }

  if ('created_at' in nextRow && (options?.forceNewIdentity || !Number(nextRow.created_at))) {
    nextRow.created_at = now;
  }
  if ('updated_at' in nextRow) {
    nextRow.updated_at = now;
  }

  return nextRow;
}

interface SectionPanelProps {
  toolId: string;
  sectionKey: string;
  section: ToolSectionConfig | undefined;
  mode: SectionStorageMode;
  items: EditableRow[];
  relationContext: DashboardRelationContext;
  onChange: (items: EditableRow[]) => void;
}

function SectionPanel({
  toolId,
  sectionKey,
  section,
  mode,
  items,
  relationContext,
  onChange,
}: SectionPanelProps) {
  const isSingleMode = mode === 'single';
  const [query, setQuery] = useState('');
  const [editorKey, setEditorKey] = useState<EditorKey>(items.length > 0 ? 0 : null);
  const [draftRow, setDraftRow] = useState<EditableRow | null>(
    items.length > 0 ? cloneData(items[0]) : null,
  );
  const [error, setError] = useState<string | null>(null);
  const [revealedFields, setRevealedFields] = useState<Record<string, boolean>>({});
  const [mobilePane, setMobilePane] = useState<MobilePane>('list');

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

  useEffect(() => {
    setRevealedFields({});
  }, [editorKey, sectionKey]);

  useEffect(() => {
    setMobilePane('list');
  }, [sectionKey]);

  const filteredItems = useMemo(() => {
    if (!query.trim()) {
      return items.map((item, index) => ({ item, index }));
    }
    const keyword = query.trim().toLowerCase();
    return items
      .map((item, index) => ({ item, index }))
      .filter(({ item }) =>
        Object.values(item).some((v) => String(v ?? '').toLowerCase().includes(keyword)),
      );
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
    setMobilePane('editor');
  };

  const startEdit = (index: number) => {
    setEditorKey(index);
    setDraftRow(cloneData(items[index]));
    setError(null);
    setMobilePane('editor');
  };

  const saveRow = () => {
    if (!draftRow) {
      return;
    }
    try {
      const nextDraft = prepareRowForSave(section, draftRow, items, {
        forceNewIdentity: editorKey === 'new',
      });
      if (editorKey === 'new') {
        onChange([...items, nextDraft]);
        setEditorKey(items.length);
      } else if (typeof editorKey === 'number') {
        onChange(items.map((item, index) => (index === editorKey ? nextDraft : item)));
      }
      setDraftRow(nextDraft);
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
    setMobilePane(nextItems[0] ? 'editor' : 'list');
  };

  const duplicateCurrent = () => {
    if (!draftRow) {
      return;
    }
    const nextRow = prepareRowForSave(section, draftRow, items, { forceNewIdentity: true });
    onChange([...items, nextRow]);
  };

  const toggleMaskedField = (fieldKey: string) => {
    setRevealedFields((current) => ({
      ...current,
      [fieldKey]: !current[fieldKey],
    }));
  };

  const showListPane = mobilePane === 'list';
  const showEditorPane = mobilePane === 'editor';

  const renderFieldHeader = (field: ToolFieldConfig, revealed: boolean) => (
    <div className="flex items-center justify-between gap-3">
      <span className="font-medium">{field.label}</span>
      {isMaskedField(field) ? (
        <button
          type="button"
          aria-label={`${revealed ? '隐藏' : '显示'} ${field.label}`}
          onClick={() => toggleMaskedField(field.key)}
          className="inline-flex h-8 w-8 items-center justify-center rounded-full border border-slate-200 bg-white text-slate-600 transition hover:border-brand-200 hover:bg-brand-50 hover:text-brand-700"
        >
          {revealed ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
        </button>
      ) : null}
    </div>
  );

  return (
    <div className="space-y-4">
      <div className="rounded-3xl border border-slate-200/70 bg-slate-50/80 p-1 xl:hidden">
        <div className="grid grid-cols-2 gap-1">
          <button
            type="button"
            aria-pressed={showListPane}
            onClick={() => setMobilePane('list')}
            className={cn(
              'h-11 rounded-2xl text-sm font-medium transition',
              showListPane ? 'bg-white text-ink shadow-sm' : 'text-slate-600 hover:bg-white/70',
            )}
          >
            列表
          </button>
          <button
            type="button"
            aria-pressed={showEditorPane}
            onClick={() => setMobilePane('editor')}
            className={cn(
              'h-11 rounded-2xl text-sm font-medium transition',
              showEditorPane ? 'bg-white text-ink shadow-sm' : 'text-slate-600 hover:bg-white/70',
            )}
          >
            编辑器
          </button>
        </div>
      </div>
      <div className="grid gap-5 xl:grid-cols-[1.3fr_1fr]">
        <section
          className={cn(
            showListPane ? 'block' : 'hidden',
            'rounded-4xl border border-slate-200/70 bg-white/75 p-5 shadow-panel xl:block',
          )}
        >
        <div className="flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
          <div>
            <h3 className="text-lg font-semibold text-ink">{section?.label ?? sectionKey}</h3>
            <p className="mt-1 text-sm text-slate-600">
              {section?.description ?? '当前区块使用通用数据维护视图。'}
            </p>
          </div>
          <div className="flex flex-wrap gap-2">
            {!isSingleMode ? (
              <input
                value={query}
                onChange={(event) => setQuery(event.target.value)}
                placeholder="搜索当前区块"
                className="h-10 rounded-full border border-slate-200 bg-slate-50 px-4 text-sm outline-none transition focus:border-brand-400 focus:bg-white"
              />
            ) : null}
            {!section?.readOnly && (!isSingleMode || items.length === 0) ? (
              <button
                type="button"
                onClick={startCreate}
                className="h-10 rounded-full bg-brand-700 px-4 text-sm font-medium text-white transition hover:bg-brand-800"
              >
                {isSingleMode ? '初始化配置' : '新增记录'}
              </button>
            ) : null}
          </div>
        </div>
        <div className="mt-5 overflow-hidden rounded-3xl border border-slate-100">
          <div className="hidden grid-cols-[96px_repeat(4,minmax(0,1fr))] gap-3 bg-slate-50 px-4 py-3 text-[11px] font-medium tracking-[0.16em] text-slate-400 lg:grid">
            <span className="min-w-0 leading-5">操作</span>
            {previewKeys.map((key) => (
              <span key={key} className="min-w-0 leading-5">
                {getFieldByKey(section, key, items).label}
              </span>
            ))}
          </div>
          <div className="divide-y divide-slate-100">
            {filteredItems.length === 0 ? (
              <div className="px-4 py-10 text-center text-sm text-slate-500">
                {isSingleMode ? '当前配置为空，可点击右上角初始化。' : '暂无匹配结果，可尝试新增或调整筛选词。'}
              </div>
            ) : (
              filteredItems.map(({ item, index }) => {
                const isSelected = editorKey === index;
                const itemKey = item.id != null ? `${sectionKey}-id-${item.id}` : `${sectionKey}-${index}`;
                return (
                  <button
                    key={itemKey}
                    type="button"
                    onClick={() => startEdit(index)}
                    className={cn(
                      'grid w-full gap-3 px-4 py-4 text-left transition lg:grid-cols-[96px_repeat(4,minmax(0,1fr))] lg:items-start',
                      isSelected ? 'bg-brand-50/70' : 'bg-white hover:bg-slate-50',
                    )}
                  >
                    <span className="text-xs font-medium text-brand-700">{isSingleMode ? '编辑配置' : '编辑记录'}</span>
                    {previewKeys.map((key) => {
                      const previewField = getFieldByKey(section, key, items);
                      const maskedPreview = isMaskedField(previewField);
                      const friendlyValue = formatFriendlyValue({
                        toolId,
                        sectionKey,
                        fieldKey: key,
                        value: item[key],
                        row: item,
                        context: relationContext,
                      });
                      const rawTitle = maskedPreview ? getMaskedValue(item[key]) : formatPreviewText(item[key]);
                      const friendlyTitle = maskedPreview
                        ? getMaskedValue(item[key])
                        : formatPreviewText(friendlyValue);
                      const rawText = maskedPreview ? rawTitle : truncateJsonPreview(rawTitle);
                      const friendlyText = maskedPreview ? friendlyTitle : truncateJsonPreview(friendlyTitle);
                      return (
                        <span key={key} className="min-w-0 flex flex-col gap-1 text-sm text-slate-600">
                          <span
                            className="min-w-0 font-medium leading-6 text-ink [overflow-wrap:anywhere]"
                            title={friendlyTitle}
                          >
                            {friendlyText}
                          </span>
                          {!maskedPreview && friendlyText !== rawText ? (
                            <span
                              className="min-w-0 text-xs leading-5 text-slate-400 [overflow-wrap:anywhere]"
                              title={`原始值：${rawTitle}`}
                            >
                              原始值：{rawText}
                            </span>
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

        <section
          className={cn(
            showEditorPane ? 'block' : 'hidden',
            'rounded-4xl border border-slate-200/70 bg-white/75 p-5 shadow-panel xl:block',
          )}
        >
          <div className="flex items-center justify-between gap-3">
          <div>
            <h3 className="text-lg font-semibold text-ink">{isSingleMode ? '配置编辑器' : '记录编辑器'}</h3>
            <p className="mt-1 text-sm text-slate-600">
              {isSingleMode ? '修改当前区块的配置项，最后统一点击顶部“保存到后端”。' : '修改当前区块的单条记录，最后统一点击顶部“保存到后端”。'}
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
              const isLocked = isSensitiveField(section, field);
              const isDisabled = Boolean(section?.readOnly || isLocked);
              const readOnlyHint = getFieldReadOnlyHint(section, field);
              const isMasked = isMaskedField(field);
              const isRevealed = Boolean(revealedFields[field.key]);
              const maskedValue = getMaskedValue(toInputValue(field, value));

              if (field.type === 'boolean') {
                return (
                  <label
                    key={field.key}
                    className="flex items-center gap-3 rounded-3xl bg-slate-50 px-4 py-3 text-sm text-slate-700"
                  >
                    <input
                      type="checkbox"
                      checked={Boolean(value)}
                      disabled={isDisabled}
                      onChange={(event) =>
                        setDraftRow((current) => ({
                          ...(current ?? {}),
                          [field.key]: event.target.checked,
                        }))
                      }
                    />
                    <span>{field.label}</span>
                    {readOnlyHint ? <span className="text-xs text-slate-500">{readOnlyHint}</span> : null}
                  </label>
                );
              }

              if (editorMeta.kind === 'select') {
                return (
                  <label key={field.key} className="block space-y-2 text-sm text-slate-700">
                    {renderFieldHeader(field, isRevealed)}
                    <select
                      aria-label={field.label}
                      value={value === null || value === undefined ? '' : String(value)}
                      disabled={isDisabled}
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
                    {readOnlyHint ? <p className="text-xs text-slate-500">{readOnlyHint}</p> : null}
                  </label>
                );
              }

              if (field.type === 'textarea' || field.type === 'json') {
                return (
                  <label key={field.key} className="block space-y-2 text-sm text-slate-700">
                    {renderFieldHeader(field, isRevealed)}
                    <textarea
                      aria-label={field.label}
                      value={isMasked && !isRevealed ? maskedValue : String(toInputValue(field, value))}
                      disabled={isDisabled}
                      readOnly={!isDisabled && isMasked && !isRevealed}
                      onChange={(event) => {
                        setDraftRow((current) => {
                          try {
                            return {
                              ...(current ?? {}),
                              [field.key]: fromInputValue(field, event.target.value, current?.[field.key]),
                            };
                          } catch (parseError) {
                            setError(
                              compactJsonErrorMessage(parseError, `${field.label} JSON 解析失败`),
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
                    {isMasked && !isRevealed ? (
                      <p className="text-xs text-slate-500">当前已掩码，点击右侧眼睛后可查看和编辑。</p>
                    ) : null}
                    {readOnlyHint ? <p className="text-xs text-slate-500">{readOnlyHint}</p> : null}
                  </label>
                );
              }

              return (
                <label key={field.key} className="block space-y-2 text-sm text-slate-700">
                  {renderFieldHeader(field, isRevealed)}
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
                    value={isMasked && !isRevealed ? maskedValue : String(toInputValue(field, value))}
                    disabled={isDisabled}
                    readOnly={!isDisabled && isMasked && !isRevealed}
                    onChange={(event) =>
                      setDraftRow((current) => ({
                        ...(current ?? {}),
                        [field.key]: fromInputValue(field, event.target.value, current?.[field.key]),
                      }))
                    }
                    className="h-12 w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 outline-none transition focus:border-brand-400 focus:bg-white"
                  />
                  {!isMasked && friendlyText !== String(toInputValue(field, value) || '—') ? (
                    <p className="text-xs text-slate-500">当前展示：{friendlyText}</p>
                  ) : null}
                  {isMasked && !isRevealed ? (
                    <p className="text-xs text-slate-500">当前已掩码，点击右侧眼睛后可查看和编辑。</p>
                  ) : null}
                  {readOnlyHint ? <p className="text-xs text-slate-500">{readOnlyHint}</p> : null}
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
                    {isSingleMode ? '保存当前配置' : '保存当前记录'}
                  </button>
                  {!isSingleMode ? (
                    <>
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
                </>
              ) : null}
            </div>
          </div>
        ) : (
          <div className="mt-5 rounded-3xl border border-dashed border-slate-200 bg-slate-50 px-4 py-10 text-center text-sm text-slate-500">
            {isSingleMode ? '当前配置为空，可点击右上角初始化。' : '先从左侧选择一条记录，或新增一条空记录开始编辑。'}
          </div>
        )}
        <div className="mt-5 rounded-3xl bg-slate-50 px-4 py-3 text-sm text-slate-600">
          <p>{isSingleMode ? `当前区块状态：${items[0] ? '已配置' : '未配置'}` : `当前区块条数：${items.length}`}</p>
          <p className="mt-1">
            最近更新时间：{draftRow?.updated_at ? formatTimestamp(Number(draftRow.updated_at)) : '—'}
          </p>
          <p className="mt-1">工具：{getToolConfig(toolId).name}</p>
        </div>
        </section>
      </div>
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
  const currentSectionMode = activeSection
    ? resolveSectionMode(draftData, activeSection, currentSection)
    : 'list';

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
          mode={currentSectionMode}
          items={getSectionItems(draftData, activeSection, currentSection)}
          relationContext={relationContext}
          onChange={(items) =>
            setDraftData((current) => writeSectionData(current, activeSection, currentSectionMode, items))
          }
        />
      ) : (
        <div className="rounded-4xl border border-dashed border-slate-200 bg-slate-50 px-6 py-16 text-center text-sm text-slate-500">
          当前工具暂无可管理区块。
        </div>
      )}
    </section>
  );
}
