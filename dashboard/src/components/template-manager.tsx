'use client';

import { useEffect, useState } from 'react';
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

export function TemplateManager({ userId }: TemplateManagerProps) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [data, setData] = useState<WorkPhotoTemplateData | null>(null);
  const [selectedTemplateId, setSelectedTemplateId] = useState<number | null>(null);

  const loadTemplates = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetchDashboardTool(userId, 'work_photo');
      const toolData = response.tool.data as unknown as WorkPhotoTemplateData;
      setData(toolData);
      // 默认选择第一个模板
      if (toolData.templates.length > 0 && toolData.templates[0].id) {
        setSelectedTemplateId(toolData.templates[0].id);
      }
    } catch (err) {
      setError(getActionErrorMessage(err));
      // 如果工具数据不存在，初始化空数据
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

  const addTemplate = async () => {
    if (!data) return;
    const now = Date.now();
    const maxSortIndex = Math.max(0, ...data.templates.map((t) => t.sort_index));
    const newTemplate: WorkPhotoTemplate = {
      id: Date.now(), // 临时 ID
      name: '新模板',
      sort_index: maxSortIndex + 1,
      is_archived: 0,
      created_at: now,
      updated_at: now,
    };
    const newData = {
      ...data,
      templates: [...data.templates, newTemplate],
    };
    await saveData(newData);
    setSelectedTemplateId(newTemplate.id);
  };

  const updateTemplate = async (id: number, updates: Partial<WorkPhotoTemplate>) => {
    if (!data) return;
    const newData = {
      ...data,
      templates: data.templates.map((t) =>
        t.id === id ? { ...t, ...updates, updated_at: Date.now() } : t
      ),
    };
    await saveData(newData);
  };

  const deleteTemplate = async (id: number) => {
    if (!data) return;
    if (!confirm('确定要删除此模板吗？相关的层级、选项和拍摄项也会被删除。')) return;
    const newData = {
      ...data,
      templates: data.templates.filter((t) => t.id !== id),
      hierarchy_levels: data.hierarchy_levels.filter((l) => l.template_id !== id),
      hierarchy_options: data.hierarchy_options.filter((o) => {
        const level = data.hierarchy_levels.find((l) => l.id === o.level_id);
        return level?.template_id !== id;
      }),
      capture_items: data.capture_items.filter((i) => i.template_id !== id),
    };
    await saveData(newData);
    if (selectedTemplateId === id) {
      setSelectedTemplateId(newData.templates[0]?.id || null);
    }
  };

  const addHierarchyLevel = async () => {
    if (!data || selectedTemplateId === null) return;
    const now = Date.now();
    const templateLevels = data.hierarchy_levels.filter((l) => l.template_id === selectedTemplateId);
    const maxSortIndex = Math.max(0, ...templateLevels.map((l) => l.sort_index));
    const newLevel: WorkPhotoHierarchyLevel = {
      id: Date.now(),
      template_id: selectedTemplateId,
      parent_level_id: null,
      name: '新层级',
      sort_index: maxSortIndex + 1,
      is_required: 1,
      is_archived: 0,
      created_at: now,
      updated_at: now,
    };
    await saveData({
      ...data,
      hierarchy_levels: [...data.hierarchy_levels, newLevel],
    });
  };

  const updateHierarchyLevel = async (id: number, updates: Partial<WorkPhotoHierarchyLevel>) => {
    if (!data) return;
    await saveData({
      ...data,
      hierarchy_levels: data.hierarchy_levels.map((l) =>
        l.id === id ? { ...l, ...updates, updated_at: Date.now() } : l
      ),
    });
  };

  const deleteHierarchyLevel = async (id: number) => {
    if (!data) return;
    if (!confirm('确定要删除此层级吗？相关的子层级、选项和拍摄项也会被删除。')) return;
    // 找出所有子层级
    const childLevelIds = new Set<number>();
    const findChildren = (parentId: number) => {
      data.hierarchy_levels
        .filter((l) => l.parent_level_id === parentId)
        .forEach((l) => {
          if (l.id) {
            childLevelIds.add(l.id);
            findChildren(l.id);
          }
        });
    };
    findChildren(id);
    childLevelIds.add(id);

    await saveData({
      ...data,
      hierarchy_levels: data.hierarchy_levels.filter((l) => !childLevelIds.has(l.id || 0)),
      hierarchy_options: data.hierarchy_options.filter((o) => !childLevelIds.has(o.level_id)),
      capture_items: data.capture_items.filter((i) => !childLevelIds.has(i.parent_level_id || 0)),
    });
  };

  const addHierarchyOption = async (levelId: number) => {
    if (!data) return;
    const now = Date.now();
    const levelOptions = data.hierarchy_options.filter((o) => o.level_id === levelId);
    const maxSortIndex = Math.max(0, ...levelOptions.map((o) => o.sort_index));
    const newOption: WorkPhotoHierarchyOption = {
      id: Date.now(),
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
      hierarchy_options: data.hierarchy_options.map((o) =>
        o.id === id ? { ...o, ...updates, updated_at: Date.now() } : o
      ),
    });
  };

  const deleteHierarchyOption = async (id: number) => {
    if (!data) return;
    await saveData({
      ...data,
      hierarchy_options: data.hierarchy_options.filter((o) => o.id !== id),
    });
  };

  const addCaptureItem = async () => {
    if (!data || selectedTemplateId === null) return;
    const now = Date.now();
    const templateItems = data.capture_items.filter((i) => i.template_id === selectedTemplateId);
    const maxSortIndex = Math.max(0, ...templateItems.map((i) => i.sort_index));
    const newItem: WorkPhotoCaptureItem = {
      id: Date.now(),
      template_id: selectedTemplateId,
      parent_level_id: null,
      name: '新拍摄项',
      sort_index: maxSortIndex + 1,
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
  };

  const updateCaptureItem = async (id: number, updates: Partial<WorkPhotoCaptureItem>) => {
    if (!data) return;
    await saveData({
      ...data,
      capture_items: data.capture_items.map((i) =>
        i.id === id ? { ...i, ...updates, updated_at: Date.now() } : i
      ),
    });
  };

  const deleteCaptureItem = async (id: number) => {
    if (!data) return;
    await saveData({
      ...data,
      capture_items: data.capture_items.filter((i) => i.id !== id),
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

  const selectedTemplate = data.templates.find((t) => t.id === selectedTemplateId);
  const templateLevels = data.hierarchy_levels
    .filter((l) => l.template_id === selectedTemplateId && l.is_archived === 0)
    .sort((a, b) => a.sort_index - b.sort_index);
  const templateItems = data.capture_items
    .filter((i) => i.template_id === selectedTemplateId && i.is_archived === 0)
    .sort((a, b) => a.sort_index - b.sort_index);

  return (
    <div className="space-y-6">
      {error && (
        <div className="rounded-3xl border border-rose-100 bg-rose-50/70 p-4 text-sm text-rose-600">
          {error}
        </div>
      )}

      {/* 模板列表 */}
      <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
        <div className="flex items-center justify-between">
          <h2 className="text-xl font-semibold text-ink">模板列表</h2>
          <button
            type="button"
            onClick={() => void addTemplate()}
            disabled={saving}
            className="inline-flex h-10 items-center justify-center rounded-full bg-brand-600 px-4 text-sm font-semibold text-white transition hover:bg-brand-700 disabled:opacity-50"
          >
            + 新建模板
          </button>
        </div>
        <div className="mt-4 space-y-2">
          {data.templates.length === 0 ? (
            <p className="rounded-3xl border border-slate-200 bg-slate-50 p-4 text-center text-sm text-slate-500">
              暂无模板，点击上方按钮创建第一个模板
            </p>
          ) : (
            data.templates.map((template) => (
              <div
                key={template.id}
                className={`flex items-center justify-between rounded-3xl border p-4 transition ${
                  template.id === selectedTemplateId
                    ? 'border-brand-300 bg-brand-50/50'
                    : 'border-slate-200 bg-white hover:border-slate-300'
                }`}
              >
                <button
                  type="button"
                  onClick={() => setSelectedTemplateId(template.id)}
                  className="flex-1 text-left"
                >
                  <span className="font-medium text-slate-900">{template.name}</span>
                  <span className="ml-2 text-xs text-slate-500">
                    (排序: {template.sort_index})
                  </span>
                </button>
                <button
                  type="button"
                  onClick={() => void deleteTemplate(template.id!)}
                  disabled={saving}
                  className="ml-4 text-sm text-rose-600 hover:text-rose-700 disabled:opacity-50"
                >
                  删除
                </button>
              </div>
            ))
          )}
        </div>
      </section>

      {/* 模板详情编辑 */}
      {selectedTemplate && (
        <>
          <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
            <h3 className="text-lg font-semibold text-ink">模板信息</h3>
            <div className="mt-4 space-y-4">
              <div>
                <label className="block text-sm font-medium text-slate-700">模板名称</label>
                <input
                  type="text"
                  value={selectedTemplate.name}
                  onChange={(e) =>
                    void updateTemplate(selectedTemplate.id!, { name: e.target.value })
                  }
                  disabled={saving}
                  className="mt-1 block w-full rounded-2xl border border-slate-200 bg-white px-4 py-2 text-sm text-slate-900 shadow-sm transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
                />
              </div>
              <div>
                <label className="block text-sm font-medium text-slate-700">排序索引</label>
                <input
                  type="number"
                  value={selectedTemplate.sort_index}
                  onChange={(e) =>
                    void updateTemplate(selectedTemplate.id!, {
                      sort_index: parseInt(e.target.value) || 0,
                    })
                  }
                  disabled={saving}
                  className="mt-1 block w-full rounded-2xl border border-slate-200 bg-white px-4 py-2 text-sm text-slate-900 shadow-sm transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
                />
              </div>
            </div>
          </section>

          {/* 层级结构 */}
          <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-lg font-semibold text-ink">层级结构</h3>
                <p className="mt-1 text-sm text-slate-600">
                  定义拍摄项目的组织层级，如"楼栋 &gt; 楼层 &gt; 房间"
                </p>
              </div>
              <button
                type="button"
                onClick={() => void addHierarchyLevel()}
                disabled={saving}
                className="inline-flex h-10 items-center justify-center rounded-full bg-brand-600 px-4 text-sm font-semibold text-white transition hover:bg-brand-700 disabled:opacity-50"
              >
                + 添加层级
              </button>
            </div>
            <div className="mt-4 space-y-4">
              {templateLevels.length === 0 ? (
                <p className="rounded-3xl border border-slate-200 bg-slate-50 p-4 text-center text-sm text-slate-500">
                  暂无层级，点击上方按钮添加
                </p>
              ) : (
                templateLevels.map((level) => {
                  const levelOptions = data.hierarchy_options
                    .filter((o) => o.level_id === level.id && o.is_archived === 0)
                    .sort((a, b) => a.sort_index - b.sort_index);
                  return (
                    <div key={level.id} className="rounded-3xl border border-slate-200 bg-white p-4">
                      <div className="flex items-start gap-4">
                        <div className="flex-1 space-y-3">
                          <div>
                            <label className="block text-xs font-medium text-slate-600">
                              层级名称
                            </label>
                            <input
                              type="text"
                              value={level.name}
                              onChange={(e) =>
                                void updateHierarchyLevel(level.id!, { name: e.target.value })
                              }
                              disabled={saving}
                              className="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
                            />
                          </div>
                          <div className="flex gap-3">
                            <div className="flex-1">
                              <label className="block text-xs font-medium text-slate-600">
                                排序索引
                              </label>
                              <input
                                type="number"
                                value={level.sort_index}
                                onChange={(e) =>
                                  void updateHierarchyLevel(level.id!, {
                                    sort_index: parseInt(e.target.value) || 0,
                                  })
                                }
                                disabled={saving}
                                className="mt-1 block w-full rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
                              />
                            </div>
                            <div className="flex items-end">
                              <label className="flex items-center gap-2 text-sm">
                                <input
                                  type="checkbox"
                                  checked={level.is_required === 1}
                                  onChange={(e) =>
                                    void updateHierarchyLevel(level.id!, {
                                      is_required: e.target.checked ? 1 : 0,
                                    })
                                  }
                                  disabled={saving}
                                  className="rounded border-slate-300 text-brand-600 transition focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
                                />
                                <span className="text-slate-700">必填</span>
                              </label>
                            </div>
                          </div>
                          {/* 选项列表 */}
                          <div className="space-y-2 border-t border-slate-100 pt-3">
                            <div className="flex items-center justify-between">
                              <span className="text-xs font-medium text-slate-600">选项列表</span>
                              <button
                                type="button"
                                onClick={() => void addHierarchyOption(level.id!)}
                                disabled={saving}
                                className="text-xs text-brand-600 hover:text-brand-700 disabled:opacity-50"
                              >
                                + 添加选项
                              </button>
                            </div>
                            {levelOptions.length === 0 ? (
                              <p className="rounded-xl border border-slate-100 bg-slate-50 p-2 text-center text-xs text-slate-400">
                                暂无选项
                              </p>
                            ) : (
                              <div className="space-y-1">
                                {levelOptions.map((option) => (
                                  <div
                                    key={option.id}
                                    className="flex items-center gap-2 rounded-xl border border-slate-100 bg-slate-50 p-2"
                                  >
                                    <input
                                      type="text"
                                      value={option.name}
                                      onChange={(e) =>
                                        void updateHierarchyOption(option.id!, {
                                          name: e.target.value,
                                        })
                                      }
                                      disabled={saving}
                                      className="flex-1 rounded-lg border-0 bg-white px-2 py-1 text-xs text-slate-900 transition focus:outline-none focus:ring-1 focus:ring-brand-500/40 disabled:opacity-50"
                                    />
                                    <input
                                      type="number"
                                      value={option.sort_index}
                                      onChange={(e) =>
                                        void updateHierarchyOption(option.id!, {
                                          sort_index: parseInt(e.target.value) || 0,
                                        })
                                      }
                                      disabled={saving}
                                      placeholder="排序"
                                      className="w-16 rounded-lg border-0 bg-white px-2 py-1 text-xs text-slate-900 transition focus:outline-none focus:ring-1 focus:ring-brand-500/40 disabled:opacity-50"
                                    />
                                    <button
                                      type="button"
                                      onClick={() => void deleteHierarchyOption(option.id!)}
                                      disabled={saving}
                                      className="text-xs text-rose-600 hover:text-rose-700 disabled:opacity-50"
                                    >
                                      删除
                                    </button>
                                  </div>
                                ))}
                              </div>
                            )}
                          </div>
                        </div>
                        <button
                          type="button"
                          onClick={() => void deleteHierarchyLevel(level.id!)}
                          disabled={saving}
                          className="text-sm text-rose-600 hover:text-rose-700 disabled:opacity-50"
                        >
                          删除层级
                        </button>
                      </div>
                    </div>
                  );
                })
              )}
            </div>
          </section>

          {/* 拍摄项 */}
          <section className="rounded-4xl border border-slate-200/80 bg-white/85 p-6 shadow-panel">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-lg font-semibold text-ink">拍摄项</h3>
                <p className="mt-1 text-sm text-slate-600">
                  定义需要拍摄的项目，如"门、窗、墙面、地面"等
                </p>
              </div>
              <button
                type="button"
                onClick={() => void addCaptureItem()}
                disabled={saving}
                className="inline-flex h-10 items-center justify-center rounded-full bg-brand-600 px-4 text-sm font-semibold text-white transition hover:bg-brand-700 disabled:opacity-50"
              >
                + 添加拍摄项
              </button>
            </div>
            <div className="mt-4 space-y-2">
              {templateItems.length === 0 ? (
                <p className="rounded-3xl border border-slate-200 bg-slate-50 p-4 text-center text-sm text-slate-500">
                  暂无拍摄项，点击上方按钮添加
                </p>
              ) : (
                templateItems.map((item) => (
                  <div
                    key={item.id}
                    className="flex items-center gap-3 rounded-3xl border border-slate-200 bg-white p-3"
                  >
                    <input
                      type="text"
                      value={item.name}
                      onChange={(e) => void updateCaptureItem(item.id!, { name: e.target.value })}
                      disabled={saving}
                      placeholder="拍摄项名称"
                      className="flex-1 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
                    />
                    <input
                      type="number"
                      value={item.sort_index}
                      onChange={(e) =>
                        void updateCaptureItem(item.id!, {
                          sort_index: parseInt(e.target.value) || 0,
                        })
                      }
                      disabled={saving}
                      placeholder="排序"
                      className="w-20 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
                    />
                    <input
                      type="number"
                      value={item.min_count}
                      onChange={(e) =>
                        void updateCaptureItem(item.id!, {
                          min_count: parseInt(e.target.value) || 0,
                        })
                      }
                      disabled={saving}
                      placeholder="最少"
                      className="w-20 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
                    />
                    <input
                      type="number"
                      value={item.max_count || ''}
                      onChange={(e) =>
                        void updateCaptureItem(item.id!, {
                          max_count: e.target.value ? parseInt(e.target.value) : null,
                        })
                      }
                      disabled={saving}
                      placeholder="最多(可选)"
                      className="w-28 rounded-xl border border-slate-200 bg-white px-3 py-1.5 text-sm text-slate-900 transition focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/20 disabled:opacity-50"
                    />
                    <button
                      type="button"
                      onClick={() => void deleteCaptureItem(item.id!)}
                      disabled={saving}
                      className="text-sm text-rose-600 hover:text-rose-700 disabled:opacity-50"
                    >
                      删除
                    </button>
                  </div>
                ))
              )}
            </div>
          </section>
        </>
      )}

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
