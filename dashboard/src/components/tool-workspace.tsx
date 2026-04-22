'use client';

import { useEffect, useMemo, useRef, useState, useTransition } from 'react';

import { BarChart3, Eye, EyeOff, LayoutTemplate } from 'lucide-react';

import { WorkLogTimeCanvasDialog } from '@/components/work-log-time-canvas-dialog';
import { WorkLogTimeChartDialog } from '@/components/work-log-time-chart-dialog';
import {
  DASHBOARD_PILL_BUTTON_MD,
  DASHBOARD_PILL_BUTTON_SM,
  DASHBOARD_PILL_BUTTON_TAB,
} from '@/lib/button-styles';
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
type CollapsiblePane = 'list' | 'editor';

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
    const checked = Boolean(value);
    if (typeof currentValue === 'number' || typeof field.defaultValue === 'number') {
      return checked ? 1 : 0;
    }
    return checked;
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
    return section.fields
      .filter((item) => !shouldHidePreviewField(section, item.key, items))
      .slice(0, 4)
      .map((item) => item.key);
  }
  const first = items[0];
  return first
    ? inferFields(first)
        .filter((item) => !shouldHidePreviewField(section, item.key, items))
        .slice(0, 4)
        .map((item) => item.key)
    : [];
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

function hasReadableCompanionField(section: ToolSectionConfig | undefined, fieldKey: string, items: EditableRow[]) {
  if (!fieldKey.endsWith('_id')) {
    return false;
  }
  const companionKey = `${fieldKey.slice(0, -3)}_title`;
  return Boolean(section?.fields?.some((item) => item.key === companionKey) || items.some((item) => companionKey in item));
}

function shouldHidePreviewField(section: ToolSectionConfig | undefined, fieldKey: string, items: EditableRow[]) {
  if (section?.idKey === fieldKey) {
    return true;
  }
  return hasReadableCompanionField(section, fieldKey, items);
}

function shouldHideEditorField(
  section: ToolSectionConfig | undefined,
  field: ToolFieldConfig,
  items: EditableRow[],
  isSelectField: boolean,
) {
  if (section?.idKey === field.key) {
    return true;
  }
  if (isSelectField) {
    return false;
  }
  return hasReadableCompanionField(section, field.key, items);
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
  toolData: Record<string, unknown>;
  sectionKey: string;
  section: ToolSectionConfig | undefined;
  mode: SectionStorageMode;
  items: EditableRow[];
  relationContext: DashboardRelationContext;
  toolDirty: boolean;
  toolSavePending: boolean;
  onCommitItems: (items: EditableRow[]) => void;
  onSaveToBackend: () => void;
  onChange: (items: EditableRow[]) => void;
}

function SectionPanel({
  toolId,
  toolData,
  sectionKey,
  section,
  mode,
  items,
  relationContext,
  toolDirty,
  toolSavePending,
  onCommitItems,
  onSaveToBackend,
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
  const [canvasOpen, setCanvasOpen] = useState(false);
  const [chartOpen, setChartOpen] = useState(false);
  const [collapsedPanes, setCollapsedPanes] = useState<Record<CollapsiblePane, boolean>>({
    list: false,
    editor: false,
  });
  const canvasTriggerRef = useRef<HTMLButtonElement | null>(null);
  const chartTriggerRef = useRef<HTMLButtonElement | null>(null);

  const supportsTreeView = toolId === 'work_log' && sectionKey === 'time_entries' && !isSingleMode;
  const workLogTasks = useMemo(
    () =>
      supportsTreeView
        ? getSectionItems(toolData, 'tasks', getSectionConfig(toolId, 'tasks'))
        : ([] as EditableRow[]),
    [supportsTreeView, toolData, toolId],
  );
  const workLogTaskTags = useMemo(
    () =>
      supportsTreeView
        ? getSectionItems(toolData, 'task_tags', getSectionConfig(toolId, 'task_tags'))
        : ([] as EditableRow[]),
    [supportsTreeView, toolData, toolId],
  );

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

  useEffect(() => {
    setCanvasOpen(false);
    setChartOpen(false);
    setCollapsedPanes({
      list: false,
      editor: false,
    });
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
    setCollapsedPanes((current) => ({
      ...current,
      editor: false,
    }));
  };

  const startEdit = (index: number) => {
    setEditorKey(index);
    setDraftRow(cloneData(items[index]));
    setError(null);
    setMobilePane('editor');
    setCollapsedPanes((current) => ({
      ...current,
      editor: false,
    }));
  };

  const buildNextItemsFromDraft = () => {
    if (!draftRow) {
      return null;
    }
    const nextDraft = prepareRowForSave(section, draftRow, items, {
      forceNewIdentity: editorKey === 'new',
    });
    if (editorKey === 'new') {
      return {
        nextDraft,
        nextItems: [...items, nextDraft],
        nextEditorKey: items.length as EditorKey,
      };
    }
    if (typeof editorKey === 'number') {
      return {
        nextDraft,
        nextItems: items.map((item, index) => (index === editorKey ? nextDraft : item)),
        nextEditorKey: editorKey,
      };
    }
    return null;
  };

  const persistDraftLocally = () => {
    const nextState = buildNextItemsFromDraft();
    if (!nextState) {
      return null;
    }
    onChange(nextState.nextItems);
    setEditorKey(nextState.nextEditorKey);
    setDraftRow(nextState.nextDraft);
    setError(null);
    return nextState;
  };

  const syncDraftRow = (nextDraft: EditableRow) => {
    setDraftRow(nextDraft);
    if (editorKey === 'new') {
      onChange([...items, nextDraft]);
      setEditorKey(items.length);
      return;
    }
    if (typeof editorKey === 'number') {
      onChange(items.map((item, index) => (index === editorKey ? nextDraft : item)));
    }
  };

  const updateDraftRow = (updater: (current: EditableRow) => EditableRow) => {
    if (!draftRow) {
      return;
    }
    syncDraftRow(updater(draftRow));
    setError(null);
  };

  const commitRowToBackend = () => {
    try {
      const nextState = persistDraftLocally();
      if (nextState) {
        onCommitItems(nextState.nextItems);
        return;
      }
      onSaveToBackend();
    } catch (saveError) {
      setError(saveError instanceof Error ? saveError.message : '保存失败');
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
  const showListSection = !collapsedPanes.list;
  const showEditorSection = !collapsedPanes.editor;
  const currentStoredRow =
    editorKey === 'new'
      ? null
      : typeof editorKey === 'number'
        ? (items[editorKey] ?? null)
        : null;
  const rowDirty = draftRow ? JSON.stringify(currentStoredRow) !== JSON.stringify(draftRow) : false;
  const previewColumnCount = Math.max(previewKeys.length, 1);
  const previewGridStyle = {
    gridTemplateColumns: `repeat(${previewColumnCount}, minmax(0, 1fr))`,
  };

  const togglePaneCollapse = (pane: CollapsiblePane) => {
    setCollapsedPanes((current) => ({
      ...current,
      [pane]: !current[pane],
    }));
  };

  const restorePane = (pane: CollapsiblePane) => {
    setCollapsedPanes((current) => ({
      ...current,
      [pane]: false,
    }));
  };

  const renderFieldHeader = (field: ToolFieldConfig, revealed: boolean) => (
    <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
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
              'min-h-11 rounded-2xl px-4 py-2 text-sm font-medium leading-5 transition',
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
              'min-h-11 rounded-2xl px-4 py-2 text-sm font-medium leading-5 transition',
              showEditorPane ? 'bg-white text-ink shadow-sm' : 'text-slate-600 hover:bg-white/70',
            )}
          >
            编辑器
          </button>
        </div>
      </div>
      {supportsTreeView ? (
        <div className="rounded-[1.75rem] border border-slate-200/80 bg-[radial-gradient(circle_at_top_right,_rgba(59,130,246,0.12),transparent_30%),linear-gradient(135deg,rgba(15,23,42,0.03),rgba(34,197,94,0.06))] p-5 shadow-panel">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[0.22em] text-brand-700">Canvas Reassign</p>
              <h3 className="mt-2 text-lg font-semibold text-ink">把工时归属整理搬到独立画布中</h3>
              <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-600">
                通过弹出式无边界画布查看任务全貌，支持缩放、拖动画布和拖拽工时卡片改归属；当前页面保留列表查阅与精细编辑。
              </p>
              <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-500">
                需要按日期回看投入分布时，可直接打开柱状图，在模态框里按任务、标签和时间范围筛选。
              </p>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="rounded-full bg-white/90 px-3 py-1 text-xs font-medium text-slate-600 shadow-sm">
                {workLogTasks.length} 个任务
              </span>
              <span className="rounded-full bg-white/90 px-3 py-1 text-xs font-medium text-slate-600 shadow-sm">
                {items.length} 条工时
              </span>
              <button
                ref={canvasTriggerRef}
                type="button"
                onClick={() => setCanvasOpen(true)}
                className={`${DASHBOARD_PILL_BUTTON_MD} bg-ink text-white hover:bg-slate-800`}
              >
                <LayoutTemplate className="h-4 w-4" />
                打开工时归属画布
              </button>
              <button
                ref={chartTriggerRef}
                type="button"
                onClick={() => setChartOpen(true)}
                className={`${DASHBOARD_PILL_BUTTON_MD} border border-brand-200 bg-white text-brand-800 hover:border-brand-300 hover:bg-brand-50`}
              >
                <BarChart3 className="h-4 w-4" />
                查看工时柱状图
              </button>
            </div>
          </div>
        </div>
      ) : null}
      {collapsedPanes.list || collapsedPanes.editor ? (
        <div className="flex flex-wrap gap-2">
          {collapsedPanes.list ? (
            <button
              type="button"
              aria-label={`展开${section?.label ?? sectionKey}面板`}
              onClick={() => restorePane('list')}
              className={`${DASHBOARD_PILL_BUTTON_SM} border border-slate-200 bg-white text-slate-700 hover:border-brand-200 hover:bg-brand-50`}
            >
              展开{section?.label ?? sectionKey}面板
            </button>
          ) : null}
          {collapsedPanes.editor ? (
            <button
              type="button"
              aria-label={`展开${isSingleMode ? '配置编辑器' : '记录编辑器'}面板`}
              onClick={() => restorePane('editor')}
              className={`${DASHBOARD_PILL_BUTTON_SM} border border-slate-200 bg-white text-slate-700 hover:border-brand-200 hover:bg-brand-50`}
            >
              展开{isSingleMode ? '配置编辑器' : '记录编辑器'}面板
            </button>
          ) : null}
        </div>
      ) : null}
      <div className={cn('grid gap-5', !collapsedPanes.list && !collapsedPanes.editor ? 'xl:grid-cols-[1.3fr_1fr]' : 'grid-cols-1')}>
        {showListSection ? (
          <section
            className={cn(
              showListPane ? 'block' : 'hidden',
              'min-w-0 rounded-4xl border border-slate-200/70 bg-white/75 p-5 shadow-panel xl:block',
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
                    placeholder={supportsTreeView ? '搜索任务或工时内容' : '搜索当前区块'}
                    className="h-10 w-full min-w-0 rounded-full border border-slate-200 bg-slate-50 px-4 text-sm outline-none transition focus:border-brand-400 focus:bg-white md:w-72"
                  />
                ) : null}
                {!section?.readOnly && (!isSingleMode || items.length === 0) ? (
                  <button
                    type="button"
                    onClick={startCreate}
                    className={`${DASHBOARD_PILL_BUTTON_SM} bg-brand-700 text-white hover:bg-brand-800`}
                  >
                    {isSingleMode ? '初始化配置' : '新增记录'}
                  </button>
                ) : null}
                <button
                  type="button"
                  aria-label={`收起${section?.label ?? sectionKey}面板`}
                  onClick={() => togglePaneCollapse('list')}
                  className={`${DASHBOARD_PILL_BUTTON_SM} border border-slate-200 bg-white text-slate-700 hover:border-brand-200 hover:bg-brand-50`}
                >
                  收起列表
                </button>
              </div>
            </div>
            {supportsTreeView ? (
              <div className="mt-4 rounded-3xl border border-slate-200 bg-slate-50/80 px-4 py-3 text-sm text-slate-600">
                想专注查看任务全貌时，可打开上方“工时归属画布”；当前列表更适合搜索、比对和快速进入记录编辑。
              </div>
            ) : null}
            <div className="mt-5 overflow-hidden rounded-3xl border border-slate-100">
              <div className="hidden gap-3 bg-slate-50 px-4 py-3 text-[11px] font-medium tracking-[0.16em] text-slate-400 lg:grid" style={previewGridStyle}>
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
                          'grid w-full gap-3 px-4 py-4 text-left transition lg:items-start',
                          isSelected ? 'bg-brand-50/70' : 'bg-white hover:bg-slate-50',
                        )}
                        style={previewGridStyle}
                      >
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
                                                    const friendlyTitle = maskedPreview
                            ? getMaskedValue(item[key])
                            : formatPreviewText(friendlyValue);
                                                    const friendlyText = maskedPreview ? friendlyTitle : truncateJsonPreview(friendlyTitle);
                          return (
                            <span key={key} className="min-w-0 flex flex-col gap-1 text-sm text-slate-600">
                              <span
                                className="min-w-0 font-medium leading-6 text-ink [overflow-wrap:anywhere]"
                                title={friendlyTitle}
                              >
                                {friendlyText}
                              </span>
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
        ) : null}

        {showEditorSection ? (
          <section
            className={cn(
              showEditorPane ? 'block' : 'hidden',
              'min-w-0 rounded-4xl border border-slate-200/70 bg-white/75 p-5 shadow-panel xl:block',
            )}
          >
            <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <h3 className="text-lg font-semibold text-ink">{isSingleMode ? '配置编辑器' : '记录编辑器'}</h3>
                <p className="mt-1 text-sm text-slate-600">
                  修改会自动保留在当前页面，点击保存即可同步到后端。
                </p>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                {section?.readOnly ? (
                  <span className="rounded-full bg-slate-100 px-3 py-1 text-xs text-slate-500">只读</span>
                ) : null}
                <button
                  type="button"
                  aria-label={`收起${isSingleMode ? '配置编辑器' : '记录编辑器'}面板`}
                  onClick={() => togglePaneCollapse('editor')}
                  className={`${DASHBOARD_PILL_BUTTON_SM} border border-slate-200 bg-white text-slate-700 hover:border-brand-200 hover:bg-brand-50`}
                >
                  收起编辑器
                </button>
              </div>
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
              const shouldHideField = shouldHideEditorField(section, field, items, editorMeta.kind === 'select');

              if (shouldHideField) {
                return null;
              }

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
                        updateDraftRow((current) => ({
                          ...current,
                          [field.key]: fromInputValue(field, event.target.checked, current[field.key]),
                        }))
                      }
                    />
                    <span>{field.label}</span>
                    {readOnlyHint ? <span className="text-xs text-slate-500">{readOnlyHint}</span> : null}
                  </label>
                );
              }

              if (editorMeta.kind === 'select') {
                const disallowEmptySelection =
                  toolId === 'work_log' && sectionKey === 'time_entries' && field.key === 'task_id';
                return (
                  <label key={field.key} className="block space-y-2 text-sm text-slate-700">
                    {renderFieldHeader(field, isRevealed)}
                    <select
                      aria-label={field.label}
                      value={value === null || value === undefined ? '' : String(value)}
                      disabled={isDisabled}
                      onChange={(event) =>
                        updateDraftRow((current) => ({
                          ...current,
                          [field.key]: coerceEditorValue(editorMeta, event.target.value),
                        }))
                      }
                      className="h-12 w-full rounded-2xl border border-slate-200 bg-slate-50 px-4 outline-none transition focus:border-brand-400 focus:bg-white"
                    >
                      <option value="" disabled={disallowEmptySelection}>
                        请选择
                      </option>
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
                        if (!draftRow) {
                          return;
                        }
                        try {
                          updateDraftRow((current) => ({
                            ...current,
                            [field.key]: fromInputValue(field, event.target.value, current[field.key]),
                          }));
                        } catch (parseError) {
                          setError(
                            compactJsonErrorMessage(parseError, `${field.label} JSON 解析失败`),
                          );
                        }
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
                      updateDraftRow((current) => ({
                        ...current,
                        [field.key]: fromInputValue(field, event.target.value, current[field.key]),
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
                    onClick={commitRowToBackend}
                    disabled={toolSavePending || (!toolDirty && !rowDirty)}
                    className={`${DASHBOARD_PILL_BUTTON_MD} bg-ink text-white hover:bg-slate-800 disabled:cursor-not-allowed disabled:bg-slate-300`}
                  >
                    {toolSavePending ? '保存中...' : '保存'}
                  </button>
                  {!isSingleMode ? (
                    <>
                      <button
                        type="button"
                        onClick={duplicateCurrent}
                        className={`${DASHBOARD_PILL_BUTTON_MD} border border-slate-200 text-slate-700 hover:border-brand-200 hover:bg-brand-50`}
                      >
                        复制一条
                      </button>
                      <button
                        type="button"
                        onClick={removeCurrent}
                        disabled={typeof editorKey !== 'number'}
                        className={`${DASHBOARD_PILL_BUTTON_MD} border border-rose-200 text-rose-600 hover:bg-rose-50 disabled:cursor-not-allowed disabled:border-slate-200 disabled:text-slate-400`}
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
        ) : null}
      </div>
      {supportsTreeView ? (
        <WorkLogTimeCanvasDialog
          open={canvasOpen}
          tasks={workLogTasks}
          taskTags={workLogTaskTags}
          tagNames={relationContext.tagNames}
          items={items}
          savePending={toolSavePending}
          onClose={() => {
            setCanvasOpen(false);
            window.requestAnimationFrame(() => {
              canvasTriggerRef.current?.focus();
            });
          }}
          onCommit={(nextItems) => {
            onChange(nextItems);
            setError(null);
          }}
          onCommitToBackend={(nextItems) => {
            onCommitItems(nextItems);
            setError(null);
          }}
        />
      ) : null}
      {supportsTreeView ? (
        <WorkLogTimeChartDialog
          open={chartOpen}
          tasks={workLogTasks}
          taskTags={workLogTaskTags}
          tagNames={relationContext.tagNames}
          items={items}
          onClose={() => {
            setChartOpen(false);
            window.requestAnimationFrame(() => {
              chartTriggerRef.current?.focus();
            });
          }}
        />
      ) : null}
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

  const save = (nextData = draftData) => {
    const payloadData = cloneData(nextData);
    setDraftData(payloadData);
    startTransition(async () => {
      const actionResult = await saveToolAction({
        userId,
        toolId: tool.tool_id,
        version: tool.version,
        data: payloadData,
      });
      setResult(actionResult);
      if (actionResult.success) {
        setBaselineData(cloneData(payloadData));
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
              className={`${DASHBOARD_PILL_BUTTON_MD} border border-slate-200 bg-white/80 text-slate-700 hover:border-brand-200 hover:bg-white disabled:cursor-not-allowed disabled:opacity-50`}
            >
              放弃修改
            </button>
            <button
              type="button"
              onClick={() => save()}
              disabled={!dirty || isPending}
              className={`${DASHBOARD_PILL_BUTTON_MD} bg-ink text-white hover:bg-slate-800 disabled:cursor-not-allowed disabled:bg-slate-300`}
            >
              {isPending ? '保存中...' : '保存'}
            </button>
          </div>
        </div>
        {result ? (
          <p
            role={result.success ? 'status' : 'alert'}
            aria-live="polite"
            className={`mt-4 text-sm ${result.success ? 'text-emerald-700' : 'text-rose-600'}`}
          >
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
                DASHBOARD_PILL_BUTTON_TAB,
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
          toolData={draftData}
          sectionKey={activeSection}
          section={currentSection}
          mode={currentSectionMode}
          items={getSectionItems(draftData, activeSection, currentSection)}
          relationContext={relationContext}
          toolDirty={dirty}
          toolSavePending={isPending}
          onCommitItems={(items) => {
            const nextData = writeSectionData(draftData, activeSection, currentSectionMode, items);
            save(nextData);
          }}
          onSaveToBackend={save}
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
