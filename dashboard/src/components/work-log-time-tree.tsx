'use client';

import { useMemo, useState } from 'react';

import { AlertTriangle, Clock3, GripVertical, ListTree } from 'lucide-react';

import { cn, formatNumber, formatTimestamp } from '@/lib/format';
import { buildWorkLogTree, reassignTimeEntryTask, type WorkLogRow } from '@/lib/work-log-tree';

interface WorkLogTimeTreeProps {
  tasks: WorkLogRow[];
  items: WorkLogRow[];
  query: string;
  selectedIndex: number | null;
  onSelect: (index: number) => void;
  onChange: (items: WorkLogRow[]) => void;
}

type DropTaskId = number | 'orphan' | null;

function toNumericId(value: unknown) {
  const numeric = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(numeric) ? numeric : null;
}

function getEntryLabel(entry: WorkLogRow) {
  return String(entry.content ?? `工时#${String(entry.id ?? 'unknown')}`);
}

function matchesKeyword(entry: WorkLogRow, keyword: string) {
  return Object.values(entry).some((value) => String(value ?? '').toLowerCase().includes(keyword));
}

export function WorkLogTimeTree({
  tasks,
  items,
  query,
  selectedIndex,
  onSelect,
  onChange,
}: WorkLogTimeTreeProps) {
  const [draggingEntryId, setDraggingEntryId] = useState<number | null>(null);
  const [activeDropTaskId, setActiveDropTaskId] = useState<DropTaskId>(null);
  const [statusMessage, setStatusMessage] = useState('');

  const selectedEntryId = selectedIndex === null ? null : toNumericId(items[selectedIndex]?.id);

  const entryIndexMap = useMemo(() => {
    const mapping = new Map<number, number>();
    items.forEach((item, index) => {
      const entryId = toNumericId(item.id);
      if (entryId !== null) {
        mapping.set(entryId, index);
      }
    });
    return mapping;
  }, [items]);

  const groups = useMemo(() => {
    const keyword = query.trim().toLowerCase();
    const tree = buildWorkLogTree(tasks, items);

    if (!keyword) {
      return tree;
    }

    return tree
      .map((group) => {
        const taskMatches = group.title.toLowerCase().includes(keyword);
        const entries = taskMatches ? group.entries : group.entries.filter((entry) => matchesKeyword(entry, keyword));
        if (!taskMatches && entries.length === 0) {
          return null;
        }
        return {
          ...group,
          entries,
          entryCount: entries.length,
          totalMinutes: entries.reduce((total, entry) => total + (toNumericId(entry.minutes) ?? 0), 0),
        };
      })
      .filter((group): group is NonNullable<typeof group> => group !== null);
  }, [items, query, tasks]);

  const handleDrop = (targetTaskId: number | null, targetTitle: string) => {
    if (draggingEntryId === null) {
      return;
    }

    const currentIndex = entryIndexMap.get(draggingEntryId);
    if (currentIndex === undefined) {
      setDraggingEntryId(null);
      setActiveDropTaskId(null);
      return;
    }

    const currentEntry = items[currentIndex];
    const currentTaskId = toNumericId(currentEntry.task_id);
    const entryLabel = getEntryLabel(currentEntry);

    if (currentTaskId === targetTaskId) {
      setStatusMessage(`“${entryLabel}”已经归属在“${targetTitle}”下`);
      setDraggingEntryId(null);
      setActiveDropTaskId(null);
      return;
    }

    const nextItems = reassignTimeEntryTask(items, draggingEntryId, targetTaskId, Date.now());
    onChange(nextItems);
    onSelect(currentIndex);
    setStatusMessage(`已将“${entryLabel}”归属到“${targetTitle}”`);
    setDraggingEntryId(null);
    setActiveDropTaskId(null);
  };

  return (
    <div className="space-y-4">
      <div className="rounded-3xl border border-dashed border-brand-200 bg-brand-50/60 px-4 py-3 text-sm text-slate-700">
        <div className="flex flex-wrap items-center gap-2 text-brand-700">
          <ListTree className="h-4 w-4" />
          <span className="font-medium">任务树视图</span>
        </div>
        <p className="mt-2 leading-6 text-slate-600">
          把工时卡片拖到目标任务，即可直接修改归属；右侧编辑器仍可继续微调日期、时长和内容。
        </p>
        <p role="status" aria-live="polite" className="mt-2 text-xs text-slate-500">
          {statusMessage || '当前支持任务节点与未归属节点之间的拖拽迁移。'}
        </p>
      </div>

      <div className="space-y-3">
        {groups.length === 0 ? (
          <div className="rounded-3xl border border-dashed border-slate-200 bg-slate-50 px-4 py-8 text-center text-sm text-slate-500">
            暂无匹配的任务或工时记录。
          </div>
        ) : (
          groups.map((group) => {
            const isActiveDropTarget =
              activeDropTaskId !== null &&
              ((group.taskId === null && activeDropTaskId === 'orphan') || group.taskId === activeDropTaskId);

            return (
              <section
                key={group.id}
                role="group"
                aria-label={`工时树节点 ${group.title}`}
                onDragOver={(event) => {
                  event.preventDefault();
                  setActiveDropTaskId(group.taskId ?? 'orphan');
                }}
                onDrop={(event) => {
                  event.preventDefault();
                  handleDrop(group.taskId, group.title);
                }}
                className={cn(
                  'rounded-3xl border bg-white p-4 shadow-sm transition',
                  isActiveDropTarget
                    ? 'border-brand-400 bg-brand-50/70 ring-2 ring-brand-200'
                    : group.isOrphan
                      ? 'border-amber-200 bg-amber-50/60'
                      : 'border-slate-200',
                )}
              >
                <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      {group.isOrphan ? (
                        <AlertTriangle className="h-4 w-4 text-amber-600" />
                      ) : (
                        <ListTree className="h-4 w-4 text-brand-700" />
                      )}
                      <h4 className="text-base font-semibold text-ink">{group.title}</h4>
                      {group.isOrphan ? (
                        <span className="rounded-full bg-amber-100 px-2.5 py-1 text-xs font-medium text-amber-700">
                          兜底节点
                        </span>
                      ) : null}
                    </div>
                    <p className="mt-2 text-sm text-slate-600">
                      {group.entryCount} 条记录 · {formatNumber(group.totalMinutes)} 分钟
                      {group.task?.estimated_minutes ? ` · 预估 ${formatNumber(Number(group.task.estimated_minutes))} 分钟` : ''}
                    </p>
                  </div>
                  <span className="inline-flex h-9 items-center rounded-full bg-slate-100 px-3 text-sm font-medium text-slate-600">
                    {group.entryCount} 条
                  </span>
                </div>

                <div className="mt-4 space-y-3">
                  {group.entries.length === 0 ? (
                    <div className="rounded-2xl border border-dashed border-slate-200 px-4 py-5 text-sm text-slate-500">
                      拖拽工时到这里，重新归属到当前任务。
                    </div>
                  ) : (
                    group.entries.map((entry) => {
                      const entryId = toNumericId(entry.id);
                      const entryIndex = entryId === null ? null : entryIndexMap.get(entryId) ?? null;
                      const isSelected = entryId !== null && entryId === selectedEntryId;

                      return (
                        <div
                          key={entryId ?? getEntryLabel(entry)}
                          role="button"
                          tabIndex={0}
                          draggable={entryId !== null}
                          aria-label={`工时记录 ${getEntryLabel(entry)}`}
                          onClick={() => {
                            if (entryIndex !== null) {
                              onSelect(entryIndex);
                            }
                          }}
                          onKeyDown={(event) => {
                            if ((event.key === 'Enter' || event.key === ' ') && entryIndex !== null) {
                              event.preventDefault();
                              onSelect(entryIndex);
                            }
                          }}
                          onDragStart={(event) => {
                            if (entryId === null) {
                              return;
                            }
                            setDraggingEntryId(entryId);
                            setStatusMessage(`正在拖拽“${getEntryLabel(entry)}”`);
                            event.dataTransfer?.setData('text/plain', String(entryId));
                          }}
                          onDragEnd={() => {
                            setDraggingEntryId(null);
                            setActiveDropTaskId(null);
                          }}
                          className={cn(
                            'cursor-pointer rounded-2xl border px-4 py-3 transition focus:outline-none focus:ring-2 focus:ring-brand-300',
                            isSelected
                              ? 'border-brand-300 bg-brand-50/80 shadow-sm'
                              : 'border-slate-200 bg-white hover:border-brand-200 hover:bg-slate-50',
                            entryId !== null ? 'cursor-grab active:cursor-grabbing' : '',
                          )}
                        >
                          <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                            <div className="min-w-0 flex-1">
                              <div className="flex flex-wrap items-center gap-2">
                                <GripVertical className="h-4 w-4 text-slate-400" />
                                <span className="truncate font-medium text-ink">{getEntryLabel(entry)}</span>
                              </div>
                              <p className="mt-2 text-sm leading-6 text-slate-500">
                                ID #{String(entry.id ?? '—')} · {formatTimestamp(Number(entry.work_date ?? entry.created_at ?? Date.now()))}
                              </p>
                            </div>
                            <div className="flex items-center gap-2 rounded-full bg-slate-100 px-3 py-1 text-sm font-medium text-slate-600">
                              <Clock3 className="h-4 w-4" />
                              {formatNumber(Number(entry.minutes ?? 0))} 分钟
                            </div>
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>
              </section>
            );
          })
        )}
      </div>
    </div>
  );
}
