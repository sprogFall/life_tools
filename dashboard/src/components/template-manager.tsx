'use client';

import { useEffect, useMemo, useState } from 'react';
import {
  ChevronDown,
  ChevronRight,
  Folder,
  FolderPlus,
  GripVertical,
  ImagePlus,
  ListPlus,
  Plus,
  Trash2,
} from 'lucide-react';
import { getActionErrorMessage } from '@/lib/error-utils';
import { fetchDashboardTool, updateDashboardTool } from '@/lib/api';
import type {
  WorkPhotoTemplate,
  WorkPhotoHierarchyLevel,
  WorkPhotoHierarchyOption,
  WorkPhotoCaptureItem,
  WorkPhotoTemplateData,
} from '@/lib/types';

interface TemplateManagerProps {
  userId: string;
}

type TreeEntry =
  | { kind: 'level'; id: number; level: WorkPhotoHierarchyLevel; depth: number; path: string[] }
  | { kind: 'item'; id: number; item: WorkPhotoCaptureItem; depth: number; path: string[] };

const ROOT_PARENT_VALUE = 'root';

export function TemplateManager({ userId }: TemplateManagerProps) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [data, setData] = useState<WorkPhotoTemplateData | null>(null);
  const [selectedTemplateId, setSelectedTemplateId] = useState<number | null>(null);
  const [expandedLevelIds, setExpandedLevelIds] = useState<Set<number>>(() => new Set());

  const loadTemplates = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetchDashboardTool(userId, 'work_photo');
      const toolData = normalizeTemplateData(response.tool.data as unknown as WorkPhotoTemplateData);
      setData(toolData);
      setExpandedLevelIds(
        new Set(toolData.hierarchy_levels.map((level) => level.id).filter(isNumber)),
      );
      if (toolData.templates.length > 0 && toolData.templates[0].id) {
        setSelectedTemplateId((current) => {
          if (current && toolData.templates.some((template) => template.id === current)) {
            return current;
          }
          return toolData.templates[0].id;
        });
      } else {
        setSelectedTemplateId(null);
      }
    } catch (err) {
      setError(getActionErrorMessage(err));
      if (String(err).includes('工具数据不存在')) {
        setData({
          templates: [],
          hierarchy_levels: [],
          hierarchy_options: [],
          capture_items: [],
        });
      }
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadTemplates();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [userId]);

  const saveData = async (newData: WorkPhotoTemplateData) => {
    setSaving(true);
    setError(null);
    try {
      await updateDashboardTool({
        userId,
        toolId: 'work_photo',
        version: 2,
        data: newData as unknown as Record<string, unknown>,
      });
      setData(newData);
    } catch (err) {
      setError(getActionErrorMessage(err));
      throw err;
    } finally {
      setSaving(false);
    }
  };

  const selectedTemplate = data?.templates.find((t) => t.id === selectedTemplateId);
  const templateLevels = useMemo(
    () =>
      (data?.hierarchy_levels ?? [])
        .filter((level) => level.template_id === selectedTemplateId && level.is_archived === 0)
        .sort(compareNodeSort),
    [data?.hierarchy_levels, selectedTemplateId],
  );
  const templateItems = useMemo(
    () =>
      (data?.capture_items ?? [])
        .filter((item) => item.template_id === selectedTemplateId && item.is_archived === 0)
        .sort(compareNodeSort),
    [data?.capture_items, selectedTemplateId],
  );
  const levelPathById = useMemo(() => buildLevelPathMap(templateLevels), [templateLevels]);
  const treeEntries = useMemo(
    () => buildTreeEntries(templateLevels, templateItems, expandedLevelIds, levelPathById),
    [expandedLevelIds, levelPathById, templateItems, templateLevels],
  );
  const rootItemCount = templateItems.filter((item) => item.parent_level_id === null).length;

  const addTemplate = async () => {
    if (!data) return;
    const now = Date.now();
    const maxSortIndex = Math.max(-1, ...data.templates.map((t) => t.sort_index));
    const newTemplate: WorkPhotoTemplate = {
      id: createLocalId(),
      name: '新模板',
      sort_index: maxSortIndex + 1,
      is_archived: 0,
      created_at: now,
      updated_at: now,
    };
    await saveData({
      ...data,
      templates: [...data.templates, newTemplate],
    });
    setSelectedTemplateId(newTemplate.id);
  };

  const updateTemplate = async (id: number, updates: Partial<WorkPhotoTemplate>) => {
    if (!data) return;
    await saveData({
      ...data,
      templates: data.templates.map((template) =>
        template.id === id ? { ...template, ...updates, updated_at: Date.now() } : template,
      ),
    });
  };

  const deleteTemplate = async (id: number) => {
    if (!data) return;
    if (!confirm('确定要删除此模板吗？相关的层级、选项和拍摄项也会被删除。')) return;
    const deletedLevelIds = new Set(
      data.hierarchy_levels
        .filter((level) => level.template_id === id)
        .map((level) => level.id)
        .filter(isNumber),
    );
    const newData = {
      ...data,
      templates: data.templates.filter((template) => template.id !== id),
      hierarchy_levels: data.hierarchy_levels.filter((level) => level.template_id !== id),
      hierarchy_options: data.hierarchy_options.filter((option) => !deletedLevelIds.has(option.level_id)),
      capture_items: data.capture_items.filter((item) => item.template_id !== id),
    };
    await saveData(newData);
    if (selectedTemplateId === id) {
      setSelectedTemplateId(newData.templates[0]?.id || null);
    }
  };

  const addHierarchyLevel = async (parentLevelId: number | null) => {
    if (!data || selectedTemplateId === null) return;
    const now = Date.now();
    const newLevel: WorkPhotoHierarchyLevel = {
      id: createLocalId(),
      template_id: selectedTemplateId,
      parent_level_id: parentLevelId,
      name: parentLevelId === null ? '新目录' : '子目录',
      sort_index: nextSortIndex(parentLevelId, templateLevels, templateItems),
      is_required: 1,
      is_archived: 0,
      created_at: now,
      updated_at: now,
    };
    await saveData({
      ...data,
      hierarchy_levels: [...data.hierarchy_levels, newLevel],
    });
    setExpandedLevelIds((current) => {
      const next = new Set(current);
      if (parentLevelId !== null) next.add(parentLevelId);
      next.add(newLevel.id!);
      return next;
    });
  };

  const updateHierarchyLevel = async (id: number, updates: Partial<WorkPhotoHierarchyLevel>) => {
    if (!data) return;
    await saveData({
      ...data,
      hierarchy_levels: data.hierarchy_levels.map((level) =>
        level.id === id ? { ...level, ...updates, updated_at: Date.now() } : level,
      ),
    });
  };

  const deleteHierarchyLevel = async (id: number) => {
    if (!data) return;
    if (!confirm('确定要删除此目录吗？目录下的子目录、选项和拍摄项也会被删除。')) return;
    const deletedLevelIds = collectDescendantLevelIds(id, data.hierarchy_levels);
    await saveData({
      ...data,
      hierarchy_levels: data.hierarchy_levels.filter((level) => !deletedLevelIds.has(level.id || 0)),
      hierarchy_options: data.hierarchy_options.filter(
        (option) => !deletedLevelIds.has(option.level_id),
      ),
      capture_items: data.capture_items.filter(
        (item) => !deletedLevelIds.has(item.parent_level_id || 0),
      ),
    });
  };

  const addHierarchyOption = async (levelId: number) => {
    if (!data) return;
    const now = Date.now();
    const levelOptions = data.hierarchy_options.filter(
      (option) => option.level_id === levelId && option.is_archived === 0,
    );
    const maxSortIndex = Math.max(-1, ...levelOptions.map((option) => option.sort_index));
    const newOption: WorkPhotoHierarchyOption = {
      id: createLocalId(),
      level_id: levelId,
      parent_option_id: null,
      name: '新选项',
      sort_index: maxSortIndex + 1,
      is_archived: 0,
      created_at: now,
      updated_at: now,
    };
    await saveData({
      ...data,
      hierarchy_options: [...data.hierarchy_options, newOption],
    });
  };

  const updateHierarchyOption = async (id: number, updates: Partial<WorkPhotoHierarchyOption>) => {
    if (!data) return;
    await saveData({
      ...data,
      hierarchy_options: data.hierarchy_options.map((option) =>
        option.id === id ? { ...option, ...updates, updated_at: Date.now() } : option,
      ),
    });
  };

  const deleteHierarchyOption = async (id: number) => {
    if (!data) return;
    await saveData({
      ...data,
      hierarchy_options: data.hierarchy_options.filter((option) => option.id !== id),
    });
  };

  const addCaptureItem = async (parentLevelId: number | null) => {
    if (!data || selectedTemplateId === null) return;
    const now = Date.now();
    const newItem: WorkPhotoCaptureItem = {
      id: createLocalId(),
      template_id: selectedTemplateId,
      parent_level_id: parentLevelId,
      name: '新拍摄项',
      sort_index: nextSortIndex(parentLevelId, templateLevels, templateItems),
      min_count: 1,
      max_count: null,
      is_archived: 0,
      created_at: now,
      updated_at: now,
    };
    await saveData({
      ...data,
      capture_items: [...data.capture_items, newItem],
    });
    if (parentLevelId !== null) {
      setExpandedLevelIds((current) => new Set(current).add(parentLevelId));
    }
  };

  const updateCaptureItem = async (id: number, updates: Partial<WorkPhotoCaptureItem>) => {
    if (!data) return;
    await saveData({
      ...data,
      capture_items: data.capture_items.map((item) =>
        item.id === id ? { ...item, ...updates, updated_at: Date.now() } : item,
      ),
    });
  };

  const deleteCaptureItem = async (id: number) => {
    if (!data) return;
    await saveData({
      ...data,
      capture_items: data.capture_items.filter((item) => item.id !== id),
    });
  };

  const moveEntry = async (entry: TreeEntry, direction: -1 | 1) => {
    if (!data) return;
    const parentLevelId = entry.kind === 'level' ? entry.level.parent_level_id : entry.item.parent_level_id;
    const siblings = getSiblingEntries(parentLevelId, templateLevels, templateItems);
    const currentIndex = siblings.findIndex((sibling) => sameEntry(sibling, entry));
    const targetIndex = currentIndex + direction;
    if (currentIndex < 0 || targetIndex < 0 || targetIndex >= siblings.length) return;
    const current = siblings[currentIndex];
    const target = siblings[targetIndex];
    const now = Date.now();

    await saveData({
      ...data,
      hierarchy_levels: data.hierarchy_levels.map((level) => {
        if (current.kind === 'level' && level.id === current.id) {
          return { ...level, sort_index: target.sortIndex, updated_at: now };
        }
        if (target.kind === 'level' && level.id === target.id) {
          return { ...level, sort_index: current.sortIndex, updated_at: now };
        }
        return level;
      }),
      capture_items: data.capture_items.map((item) => {
        if (current.kind === 'item' && item.id === current.id) {
          return { ...item, sort_index: target.sortIndex, updated_at: now };
        }
        if (target.kind === 'item' && item.id === target.id) {
          return { ...item, sort_index: current.sortIndex, updated_at: now };
        }
        return item;
      }),
    });
  };

  const toggleExpanded = (id: number) => {
    setExpandedLevelIds((current) => {
      const next = new Set(current);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  if (loading) {
    return (
      <div className="rounded-4xl border border-slate-200/80 bg-white/85 p-10 text-center text-sm text-slate-500 shadow-panel">
        正在加载模板数据…
      </div>
    );
  }

  if (error && !data) {
    return (
      <div className="rounded-4xl border border-rose-100 bg-rose-50/70 p-10 text-center text-sm text-rose-600 shadow-panel">
        <p>{error}</p>
        <button
          type="button"
          onClick={() => void loadTemplates()}
          className="mt-4 inline-flex h-10 items-center justify-center rounded-full bg-white px-4 text-sm font-semibold text-rose-600 ring-1 ring-rose-200 transition hover:bg-rose-50"
        >
          重试加载
        </button>
      </div>
    );
  }

  if (!data) return null;

  return (
    <div className="space-y-6">
      {error && (
        <div className="rounded-3xl border border-rose-100 bg-rose-50/70 p-4 text-sm text-rose-600">
          {error}
        </div>
      )}

      <section className="rounded-4xl border border-brand-100 bg-brand-50/70 p-5 shadow-panel">
        <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p className="text-xs font-semibold text-brand-700">外拍助手模板</p>
            <h2 className="mt-1 text-2xl font-semibold text-ink">树形配置工作区</h2>
            <p className="mt-2 text-sm leading-6 text-slate-600">
              先选择左侧模板，再在右侧“树形配置”中维护目录、子目录、目录选项和拍摄项。
            </p>
          </div>
          <div className="grid grid-cols-3 gap-2 text-center text-sm text-slate-600">
            <Stat label="模板" value={data.templates.filter((template) => template.is_archived === 0).length} />
            <Stat label="目录" value={templateLevels.length} />
            <Stat label="拍摄项" value={templateItems.length} />
          </div>
        </div>
      </section>

      <div className="grid gap-6 xl:grid-cols-[320px_minmax(0,1fr)]">
        <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-5 shadow-panel">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-xl font-semibold text-ink">模板列表</h2>
              <p className="mt-1 text-sm text-slate-500">选择模板后进入右侧树形配置。</p>
            </div>
            <button
              type="button"
              onClick={() => void addTemplate()}
              disabled={saving}
              className="inline-flex h-10 w-10 items-center justify-center rounded-full bg-brand-600 text-white transition hover:bg-brand-700 disabled:opacity-50"
              title="新建模板"
              aria-label="新建模板"
            >
              <Plus className="h-4 w-4" />
            </button>
          </div>
          <div className="mt-4 space-y-2">
            {data.templates.length === 0 ? (
              <p className="rounded-3xl border border-slate-200 bg-slate-50 p-4 text-center text-sm text-slate-500">
                暂无模板，点击上方按钮创建第一个模板
              </p>
            ) : (
              data.templates
                .filter((template) => template.is_archived === 0)
                .sort(compareNodeSort)
                .map((template) => {
                  const levelCount = data.hierarchy_levels.filter(
                    (level) => level.template_id === template.id && level.is_archived === 0,
                  ).length;
                  const itemCount = data.capture_items.filter(
                    (item) => item.template_id === template.id && item.is_archived === 0,
                  ).length;
                  return (
                    <div
                      key={template.id}
                      className={`rounded-3xl border p-3 transition ${
                        template.id === selectedTemplateId
                          ? 'border-brand-300 bg-brand-50/70'
                          : 'border-slate-200 bg-white hover:border-slate-300'
                      }`}
                    >
                      <button
                        type="button"
                        onClick={() => setSelectedTemplateId(template.id)}
                        className="block w-full text-left"
                      >
                        <span className="block font-medium text-slate-900">{template.name}</span>
                        <span className="mt-1 block text-xs text-slate-500">
                          目录 {levelCount} 个 / 拍摄项 {itemCount} 个 / 排序 {template.sort_index}
                        </span>
                      </button>
                      <div className="mt-3 flex justify-end">
                        <button
                          type="button"
                          onClick={() => void deleteTemplate(template.id!)}
                          disabled={saving}
                          className="inline-flex h-8 items-center gap-1 rounded-full px-2 text-xs font-medium text-rose-600 transition hover:bg-rose-50 disabled:opacity-50"
                        >
                          <Trash2 className="h-3.5 w-3.5" />
                          删除
                        </button>
                      </div>
                    </div>
                  );
                })
            )}
          </div>
        </section>

        {selectedTemplate ? (
          <section id="work-photo-tree-config" className="rounded-4xl border border-slate-200/80 bg-white/85 p-5 shadow-panel">
            <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_160px]">
              <label className="block text-sm font-medium text-slate-700">
                模板名称
                <input
                  type="text"
                  value={selectedTemplate.name}
                  onChange={(event) =>
                    void updateTemplate(selectedTemplate.id!, { name: event.target.value })
                  }
                  disabled={saving}
                  className="mt-1 block w-full rounded-2xl border border-slate-200 bg-white px-4 py-2 text-sm text-slate-900 shadow-sm transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
                />
              </label>
              <label className="block text-sm font-medium text-slate-700">
                排序
                <input
                  type="number"
                  value={selectedTemplate.sort_index}
                  onChange={(event) =>
                    void updateTemplate(selectedTemplate.id!, {
                      sort_index: parseInt(event.target.value, 10) || 0,
                    })
                  }
                  disabled={saving}
                  className="mt-1 block w-full rounded-2xl border border-slate-200 bg-white px-4 py-2 text-sm text-slate-900 shadow-sm transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
                />
              </label>
            </div>

            <div className="mt-6 flex flex-wrap items-center justify-between gap-3 border-t border-slate-100 pt-5">
              <div>
                <p className="text-xs font-semibold text-brand-700">当前模板：{selectedTemplate.name}</p>
                <h3 className="mt-1 text-xl font-semibold text-ink">树形配置：目录与拍摄项</h3>
                <p className="mt-1 text-sm text-slate-600">
                  同级目录和拍摄项按排序混排，目录下可以继续添加子目录或拍摄项。
                </p>
              </div>
              <div className="flex flex-wrap gap-2">
                <button
                  type="button"
                  onClick={() => void addHierarchyLevel(null)}
                  disabled={saving}
                  className="inline-flex h-10 items-center gap-2 rounded-full bg-slate-900 px-4 text-sm font-semibold text-white transition hover:bg-slate-800 disabled:opacity-50"
                >
                  <FolderPlus className="h-4 w-4" />
                  根目录
                </button>
                <button
                  type="button"
                  onClick={() => void addCaptureItem(null)}
                  disabled={saving}
                  className="inline-flex h-10 items-center gap-2 rounded-full bg-brand-600 px-4 text-sm font-semibold text-white transition hover:bg-brand-700 disabled:opacity-50"
                >
                  <ImagePlus className="h-4 w-4" />
                  根拍摄项
                </button>
              </div>
            </div>

            <div className="mt-4 rounded-3xl border border-slate-200 bg-slate-50/70">
              <div className="grid grid-cols-[minmax(260px,1fr)_130px_120px_170px_168px] gap-3 border-b border-slate-200 px-4 py-3 text-xs font-semibold uppercase text-slate-500">
                <span>名称</span>
                <span>排序</span>
                <span>数量/必填</span>
                <span>归属目录</span>
                <span>操作</span>
              </div>
              <div role="tree" aria-label="模板目录和拍摄项" className="divide-y divide-slate-200">
                {treeEntries.length === 0 ? (
                  <div className="p-8 text-center text-sm text-slate-500">
                    暂无目录和拍摄项，可以先创建根目录或根拍摄项。
                  </div>
                ) : (
                  treeEntries.map((entry) =>
                    entry.kind === 'level' ? (
                      <LevelTreeRow
                        key={`level-${entry.id}`}
                        entry={entry}
                        levels={templateLevels}
                        options={data.hierarchy_options}
                        saving={saving}
                        expanded={expandedLevelIds.has(entry.id)}
                        hasChildren={hasTreeChildren(entry.id, templateLevels, templateItems)}
                        onToggle={() => toggleExpanded(entry.id)}
                        onUpdateLevel={updateHierarchyLevel}
                        onDeleteLevel={deleteHierarchyLevel}
                        onAddLevel={addHierarchyLevel}
                        onAddItem={addCaptureItem}
                        onAddOption={addHierarchyOption}
                        onUpdateOption={updateHierarchyOption}
                        onDeleteOption={deleteHierarchyOption}
                        onMoveEntry={moveEntry}
                      />
                    ) : (
                      <CaptureItemTreeRow
                        key={`item-${entry.id}`}
                        entry={entry}
                        levels={templateLevels}
                        saving={saving}
                        onUpdateItem={updateCaptureItem}
                        onDeleteItem={deleteCaptureItem}
                        onMoveEntry={moveEntry}
                      />
                    ),
                  )
                )}
              </div>
            </div>

            <div className="mt-4 grid gap-3 text-sm text-slate-600 md:grid-cols-3">
              <Stat label="目录" value={templateLevels.length} />
              <Stat label="拍摄项" value={templateItems.length} />
              <Stat label="根拍摄项" value={rootItemCount} />
            </div>
          </section>
        ) : (
          <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-10 text-center text-sm text-slate-500 shadow-panel">
            请选择或新建一个模板。
          </section>
        )}
      </div>

      {saving && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/20">
          <div className="rounded-3xl bg-white p-6 shadow-2xl">
            <p className="text-sm text-slate-600">正在保存…</p>
          </div>
        </div>
      )}
    </div>
  );
}

function LevelTreeRow({
  entry,
  levels,
  options,
  saving,
  expanded,
  hasChildren,
  onToggle,
  onUpdateLevel,
  onDeleteLevel,
  onAddLevel,
  onAddItem,
  onAddOption,
  onUpdateOption,
  onDeleteOption,
  onMoveEntry,
}: {
  entry: Extract<TreeEntry, { kind: 'level' }>;
  levels: WorkPhotoHierarchyLevel[];
  options: WorkPhotoHierarchyOption[];
  saving: boolean;
  expanded: boolean;
  hasChildren: boolean;
  onToggle: () => void;
  onUpdateLevel: (id: number, updates: Partial<WorkPhotoHierarchyLevel>) => Promise<void>;
  onDeleteLevel: (id: number) => Promise<void>;
  onAddLevel: (parentLevelId: number | null) => Promise<void>;
  onAddItem: (parentLevelId: number | null) => Promise<void>;
  onAddOption: (levelId: number) => Promise<void>;
  onUpdateOption: (id: number, updates: Partial<WorkPhotoHierarchyOption>) => Promise<void>;
  onDeleteOption: (id: number) => Promise<void>;
  onMoveEntry: (entry: TreeEntry, direction: -1 | 1) => Promise<void>;
}) {
  const level = entry.level;
  const levelOptions = options
    .filter((option) => option.level_id === level.id && option.is_archived === 0)
    .sort(compareNodeSort);

  return (
    <div data-testid={`work-photo-level-${entry.id}`} role="treeitem" aria-expanded={expanded}>
      <div className="grid grid-cols-[minmax(260px,1fr)_130px_120px_170px_168px] items-start gap-3 bg-white px-4 py-3">
        <div className="min-w-0" style={{ paddingLeft: `${entry.depth * 28}px` }}>
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={onToggle}
              disabled={!hasChildren}
              className="inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-full text-slate-500 transition hover:bg-slate-100 disabled:opacity-30"
              aria-label={expanded ? `收起${level.name}` : `展开${level.name}`}
            >
              {expanded ? <ChevronDown className="h-4 w-4" /> : <ChevronRight className="h-4 w-4" />}
            </button>
            <Folder className="h-4 w-4 shrink-0 text-slate-500" />
            <input
              type="text"
              aria-label="目录名称"
              value={level.name}
              onChange={(event) => void onUpdateLevel(entry.id, { name: event.target.value })}
              disabled={saving}
              className="min-w-0 flex-1 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm font-medium text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
            />
          </div>
          <p className="mt-1 pl-16 text-xs text-slate-500">
            {entry.path.length > 0 ? entry.path.join(' / ') : '根目录'}
          </p>
        </div>
        <input
          type="number"
          aria-label="排序"
          value={level.sort_index}
          onChange={(event) =>
            void onUpdateLevel(entry.id, { sort_index: parseInt(event.target.value, 10) || 0 })
          }
          disabled={saving}
          className="rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
        />
        <label className="flex h-9 items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={level.is_required === 1}
            onChange={(event) =>
              void onUpdateLevel(entry.id, { is_required: event.target.checked ? 1 : 0 })
            }
            disabled={saving}
            className="rounded border-slate-300 text-brand-600 transition focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
          />
          必填
        </label>
        <select
          aria-label="归属目录"
          value={level.parent_level_id ?? ROOT_PARENT_VALUE}
          onChange={(event) =>
            void onUpdateLevel(entry.id, {
              parent_level_id: event.target.value === ROOT_PARENT_VALUE ? null : Number(event.target.value),
            })
          }
          disabled={saving}
          className="rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
        >
          <option value={ROOT_PARENT_VALUE}>根目录</option>
          {levels
            .filter((candidate) => candidate.id !== level.id && !isDescendantLevel(candidate.id, level.id, levels))
            .map((candidate) => (
              <option key={candidate.id} value={candidate.id ?? ROOT_PARENT_VALUE}>
                {buildLevelPath(candidate.id, levels).join(' / ') || candidate.name}
              </option>
            ))}
        </select>
        <div className="flex flex-wrap gap-1">
          <IconButton
            label={`在${level.name}下添加子目录`}
            disabled={saving}
            onClick={() => void onAddLevel(entry.id)}
          >
            <FolderPlus className="h-4 w-4" />
          </IconButton>
          <IconButton
            label={`在${level.name}下添加拍摄项`}
            disabled={saving}
            onClick={() => void onAddItem(entry.id)}
          >
            <ImagePlus className="h-4 w-4" />
          </IconButton>
          <IconButton label="上移" disabled={saving} onClick={() => void onMoveEntry(entry, -1)}>
            <GripVertical className="h-4 w-4 rotate-180" />
          </IconButton>
          <IconButton label="下移" disabled={saving} onClick={() => void onMoveEntry(entry, 1)}>
            <GripVertical className="h-4 w-4" />
          </IconButton>
          <IconButton
            label="删除目录"
            tone="danger"
            disabled={saving}
            onClick={() => void onDeleteLevel(entry.id)}
          >
            <Trash2 className="h-4 w-4" />
          </IconButton>
        </div>
      </div>
      <div className="border-t border-slate-100 bg-slate-50/70 px-4 py-3" style={{ paddingLeft: `${entry.depth * 28 + 76}px` }}>
        <div className="flex flex-wrap items-center gap-2">
          <span className="text-xs font-semibold text-slate-500">目录选项</span>
          <button
            type="button"
            onClick={() => void onAddOption(entry.id)}
            disabled={saving}
            className="inline-flex h-7 items-center gap-1 rounded-full bg-white px-2 text-xs font-medium text-brand-700 ring-1 ring-slate-200 transition hover:bg-brand-50 disabled:opacity-50"
          >
            <ListPlus className="h-3.5 w-3.5" />
            添加选项
          </button>
          {levelOptions.length === 0 && <span className="text-xs text-slate-400">暂无选项</span>}
          {levelOptions.map((option) => (
            <span
              key={option.id}
              className="inline-flex items-center gap-1 rounded-full bg-white px-2 py-1 ring-1 ring-slate-200"
            >
              <input
                type="text"
                aria-label={`${level.name}选项`}
                value={option.name}
                onChange={(event) => void onUpdateOption(option.id!, { name: event.target.value })}
                disabled={saving}
                className="w-24 border-0 bg-transparent text-xs text-slate-800 outline-none disabled:opacity-50"
              />
              <button
                type="button"
                onClick={() => void onDeleteOption(option.id!)}
                disabled={saving}
                className="text-rose-500 transition hover:text-rose-700 disabled:opacity-50"
                aria-label={`删除${option.name}`}
              >
                <Trash2 className="h-3 w-3" />
              </button>
            </span>
          ))}
        </div>
      </div>
    </div>
  );
}

function CaptureItemTreeRow({
  entry,
  levels,
  saving,
  onUpdateItem,
  onDeleteItem,
  onMoveEntry,
}: {
  entry: Extract<TreeEntry, { kind: 'item' }>;
  levels: WorkPhotoHierarchyLevel[];
  saving: boolean;
  onUpdateItem: (id: number, updates: Partial<WorkPhotoCaptureItem>) => Promise<void>;
  onDeleteItem: (id: number) => Promise<void>;
  onMoveEntry: (entry: TreeEntry, direction: -1 | 1) => Promise<void>;
}) {
  const item = entry.item;

  return (
    <div
      data-testid={`work-photo-item-${entry.id}`}
      role="treeitem"
      className="grid grid-cols-[minmax(260px,1fr)_130px_120px_170px_168px] items-start gap-3 bg-white px-4 py-3"
    >
      <div className="min-w-0" style={{ paddingLeft: `${entry.depth * 28 + 36}px` }}>
        <input
          type="text"
          aria-label="拍摄项名称"
          value={item.name}
          onChange={(event) => void onUpdateItem(entry.id, { name: event.target.value })}
          disabled={saving}
          className="w-full rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm font-medium text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
        />
        <p className="mt-1 text-xs text-slate-500">
          {entry.path.length > 0 ? entry.path.join(' / ') : '根目录'}
        </p>
      </div>
      <input
        type="number"
        aria-label="排序"
        value={item.sort_index}
        onChange={(event) =>
          void onUpdateItem(entry.id, { sort_index: parseInt(event.target.value, 10) || 0 })
        }
        disabled={saving}
        className="rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
      />
      <div className="grid grid-cols-2 gap-2">
        <input
          type="number"
          aria-label="最少张数"
          value={item.min_count}
          onChange={(event) =>
            void onUpdateItem(entry.id, { min_count: Math.max(0, parseInt(event.target.value, 10) || 0) })
          }
          disabled={saving}
          className="min-w-0 rounded-xl border border-slate-200 bg-white px-2 py-1.5 text-sm text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
        />
        <input
          type="number"
          aria-label="最多张数"
          value={item.max_count ?? ''}
          onChange={(event) =>
            void onUpdateItem(entry.id, {
              max_count: event.target.value ? Number(event.target.value) : null,
            })
          }
          disabled={saving}
          placeholder="不限"
          className="min-w-0 rounded-xl border border-slate-200 bg-white px-2 py-1.5 text-sm text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
        />
      </div>
      <select
        aria-label="归属目录"
        value={item.parent_level_id ?? ROOT_PARENT_VALUE}
        onChange={(event) =>
          void onUpdateItem(entry.id, {
            parent_level_id: event.target.value === ROOT_PARENT_VALUE ? null : Number(event.target.value),
          })
        }
        disabled={saving}
        className="rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
      >
        <option value={ROOT_PARENT_VALUE}>根目录</option>
        {levels.map((level) => (
          <option key={level.id} value={level.id ?? ROOT_PARENT_VALUE}>
            {buildLevelPath(level.id, levels).join(' / ') || level.name}
          </option>
        ))}
      </select>
      <div className="flex flex-wrap gap-1">
        <IconButton label="上移" disabled={saving} onClick={() => void onMoveEntry(entry, -1)}>
          <GripVertical className="h-4 w-4 rotate-180" />
        </IconButton>
        <IconButton label="下移" disabled={saving} onClick={() => void onMoveEntry(entry, 1)}>
          <GripVertical className="h-4 w-4" />
        </IconButton>
        <IconButton
          label="删除拍摄项"
          tone="danger"
          disabled={saving}
          onClick={() => void onDeleteItem(entry.id)}
        >
          <Trash2 className="h-4 w-4" />
        </IconButton>
      </div>
    </div>
  );
}

function IconButton({
  label,
  disabled,
  tone = 'default',
  onClick,
  children,
}: {
  label: string;
  disabled?: boolean;
  tone?: 'default' | 'danger';
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      onClick={onClick}
      disabled={disabled}
      className={`inline-flex h-8 w-8 items-center justify-center rounded-full transition disabled:opacity-50 ${
        tone === 'danger'
          ? 'text-rose-600 hover:bg-rose-50'
          : 'text-slate-600 hover:bg-slate-100'
      }`}
    >
      {children}
    </button>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-2xl border border-slate-200 bg-white px-4 py-3">
      <span className="text-xs text-slate-500">{label}</span>
      <strong className="mt-1 block text-lg font-semibold text-slate-900">{value}</strong>
    </div>
  );
}

function normalizeTemplateData(value: WorkPhotoTemplateData): WorkPhotoTemplateData {
  return {
    templates: value.templates ?? [],
    hierarchy_levels: value.hierarchy_levels ?? [],
    hierarchy_options: value.hierarchy_options ?? [],
    capture_items: value.capture_items ?? [],
  };
}

function buildTreeEntries(
  levels: WorkPhotoHierarchyLevel[],
  items: WorkPhotoCaptureItem[],
  expandedLevelIds: Set<number>,
  levelPathById: Map<number, string[]>,
) {
  const levelsByParent = groupByParent(levels);
  const itemsByParent = groupByParent(items);
  const result: TreeEntry[] = [];
  const visitedLevels = new Set<number>();

  const visit = (parentLevelId: number | null, depth: number) => {
    const entries = getSiblingEntries(parentLevelId, levelsByParent.get(parentLevelId) ?? [], itemsByParent.get(parentLevelId) ?? []);
    for (const entry of entries) {
      if (entry.kind === 'level') {
        if (visitedLevels.has(entry.id)) continue;
        visitedLevels.add(entry.id);
        const path = levelPathById.get(entry.id) ?? [];
        result.push({ kind: 'level', id: entry.id, level: entry.level, depth, path });
        if (expandedLevelIds.has(entry.id)) visit(entry.id, depth + 1);
      } else {
        result.push({
          kind: 'item',
          id: entry.id,
          item: entry.item,
          depth,
          path: entry.item.parent_level_id === null ? [] : (levelPathById.get(entry.item.parent_level_id) ?? []),
        });
      }
    }
  };

  visit(null, 0);

  for (const level of levels) {
    if (level.id === null || visitedLevels.has(level.id)) continue;
    result.push({
      kind: 'level',
      id: level.id,
      level,
      depth: 0,
      path: levelPathById.get(level.id) ?? [level.name],
    });
  }

  return result;
}

function getSiblingEntries(
  parentLevelId: number | null,
  levels: WorkPhotoHierarchyLevel[],
  items: WorkPhotoCaptureItem[],
) {
  return [
    ...levels
      .filter((level) => level.parent_level_id === parentLevelId && level.id !== null)
      .map((level) => ({
        kind: 'level' as const,
        id: level.id!,
        sortIndex: level.sort_index,
        typeOrder: 0,
        level,
      })),
    ...items
      .filter((item) => item.parent_level_id === parentLevelId && item.id !== null)
      .map((item) => ({
        kind: 'item' as const,
        id: item.id!,
        sortIndex: item.sort_index,
        typeOrder: 1,
        item,
      })),
  ].sort((a, b) => compareEntrySort(a.sortIndex, a.id, a.typeOrder, b.sortIndex, b.id, b.typeOrder));
}

function groupByParent<T extends { parent_level_id: number | null }>(rows: T[]) {
  const map = new Map<number | null, T[]>();
  for (const row of rows) {
    const parent = row.parent_level_id ?? null;
    const siblings = map.get(parent) ?? [];
    siblings.push(row);
    map.set(parent, siblings);
  }
  return map;
}

function buildLevelPathMap(levels: WorkPhotoHierarchyLevel[]) {
  return new Map(
    levels
      .filter((level) => level.id !== null)
      .map((level) => [level.id!, buildLevelPath(level.id, levels)]),
  );
}

function buildLevelPath(levelId: number | null, levels: WorkPhotoHierarchyLevel[]) {
  if (levelId === null) return [];
  const byId = new Map(levels.filter((level) => level.id !== null).map((level) => [level.id!, level]));
  const path: string[] = [];
  const visiting = new Set<number>();
  let currentId: number | null = levelId;
  while (currentId !== null && !visiting.has(currentId)) {
    visiting.add(currentId);
    const level = byId.get(currentId);
    if (!level) break;
    path.unshift(level.name);
    currentId = level.parent_level_id;
  }
  return path;
}

function hasTreeChildren(
  levelId: number,
  levels: WorkPhotoHierarchyLevel[],
  items: WorkPhotoCaptureItem[],
) {
  return (
    levels.some((level) => level.parent_level_id === levelId && level.is_archived === 0) ||
    items.some((item) => item.parent_level_id === levelId && item.is_archived === 0)
  );
}

function nextSortIndex(
  parentLevelId: number | null,
  levels: WorkPhotoHierarchyLevel[],
  items: WorkPhotoCaptureItem[],
) {
  const sortIndexes = [
    ...levels.filter((level) => level.parent_level_id === parentLevelId).map((level) => level.sort_index),
    ...items.filter((item) => item.parent_level_id === parentLevelId).map((item) => item.sort_index),
  ];
  return sortIndexes.length === 0 ? 0 : Math.max(...sortIndexes) + 1;
}

function collectDescendantLevelIds(rootId: number, levels: WorkPhotoHierarchyLevel[]) {
  const ids = new Set<number>([rootId]);
  let changed = true;
  while (changed) {
    changed = false;
    for (const level of levels) {
      if (level.id === null || ids.has(level.id)) continue;
      if (ids.has(level.parent_level_id || 0)) {
        ids.add(level.id);
        changed = true;
      }
    }
  }
  return ids;
}

function isDescendantLevel(candidateId: number | null, rootId: number | null, levels: WorkPhotoHierarchyLevel[]) {
  if (candidateId === null || rootId === null) return false;
  let current = levels.find((level) => level.id === candidateId);
  const visiting = new Set<number>();
  while (current?.parent_level_id !== null && current?.parent_level_id !== undefined) {
    if (current.parent_level_id === rootId) return true;
    if (visiting.has(current.parent_level_id)) return false;
    visiting.add(current.parent_level_id);
    current = levels.find((level) => level.id === current?.parent_level_id);
  }
  return false;
}

function sameEntry(
  a: { kind: 'level' | 'item'; id: number },
  b: { kind: 'level' | 'item'; id: number },
) {
  return a.kind === b.kind && a.id === b.id;
}

function compareNodeSort<T extends { sort_index: number; id: number | null }>(a: T, b: T) {
  const sortCompared = a.sort_index - b.sort_index;
  if (sortCompared !== 0) return sortCompared;
  return (a.id ?? 0) - (b.id ?? 0);
}

function compareEntrySort(
  aSortIndex: number,
  aId: number,
  aTypeOrder: number,
  bSortIndex: number,
  bId: number,
  bTypeOrder: number,
) {
  const sortCompared = aSortIndex - bSortIndex;
  if (sortCompared !== 0) return sortCompared;
  const typeCompared = aTypeOrder - bTypeOrder;
  if (typeCompared !== 0) return typeCompared;
  return aId - bId;
}

function isNumber(value: unknown): value is number {
  return typeof value === 'number';
}

function createLocalId() {
  return Date.now() + Math.floor(Math.random() * 1000);
}
