'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { createPortal } from 'react-dom';

import {
  BarChart3,
  BriefcaseBusiness,
  CalendarRange,
  Check,
  ChevronDown,
  Maximize2,
  Minimize2,
  Tags,
  X,
} from 'lucide-react';

import {
  DASHBOARD_PILL_BUTTON_MD,
  DASHBOARD_PILL_BUTTON_SM,
} from '@/lib/button-styles';
import { cn, formatNumber } from '@/lib/format';
import {
  buildDefaultWorkLogTimeChartFilters,
  buildWorkLogTimeChartDataset,
  type WorkLogTimeChartBar,
  type WorkLogTimeChartFilterState,
  type WorkLogTimeChartTagOption,
  type WorkLogTimeChartTaskOption,
  type WorkLogRow,
} from '@/lib/work-log-time-chart';

interface WorkLogTimeChartDialogProps {
  open: boolean;
  tasks: WorkLogRow[];
  items: WorkLogRow[];
  taskTags?: WorkLogRow[];
  tagNames?: Record<string, string>;
  onClose: () => void;
}

interface TooltipState {
  bar: WorkLogTimeChartBar;
  top: number;
  left: number;
}

type FilterPanelKind = 'task' | 'tag';

function getFilterSummary(
  selectedValues: string[],
  options: readonly { value: string; label: string }[],
  allLabel: string,
) {
  if (selectedValues.length === 0) {
    return allLabel;
  }

  if (selectedValues.length === 1) {
    return options.find((option) => option.value === selectedValues[0])?.label ?? selectedValues[0];
  }

  return `已选 ${selectedValues.length} 项`;
}

function toggleFilterValue(current: string[], value: string, orderedValues: string[]) {
  if (current.includes(value)) {
    return current.filter((item) => item !== value);
  }

  const next = [...current, value];
  return next.sort((left, right) => orderedValues.indexOf(left) - orderedValues.indexOf(right));
}

function positionTooltip(target: HTMLElement) {
  const rect = target.getBoundingClientRect();
  const left = Math.max(20, Math.min(rect.left + rect.width / 2 - 120, window.innerWidth - 260));
  const top = Math.max(20, rect.top - 92);
  return { left, top };
}

function FilterPanel({
  options,
  selectedValues,
  onToggle,
}: {
  options: readonly WorkLogTimeChartTaskOption[] | readonly WorkLogTimeChartTagOption[];
  selectedValues: string[];
  onToggle: (value: string) => void;
}) {
  if (options.length === 0) {
    return (
      <div className="rounded-3xl border border-slate-200 bg-white/90 px-4 py-3 text-sm text-slate-500">
        当前没有可筛选项。
      </div>
    );
  }

  return (
    <div className="grid gap-2 sm:grid-cols-2 xl:grid-cols-3">
      {options.map((option) => {
        const selected = selectedValues.includes(option.value);
        const swatch = 'color' in option ? option.color : '#94A3B8';

        return (
          <label
            key={option.value}
            className={cn(
              'flex cursor-pointer items-center gap-3 rounded-2xl border px-3 py-3 text-sm transition',
              selected
                ? 'border-brand-200 bg-brand-50 text-brand-900'
                : 'border-slate-200 bg-white text-slate-700 hover:border-brand-200 hover:bg-slate-50',
            )}
          >
            <input
              type="checkbox"
              className="sr-only"
              checked={selected}
              onChange={() => onToggle(option.value)}
            />
            <span className="h-3.5 w-3.5 shrink-0 rounded-full" style={{ backgroundColor: swatch }} aria-hidden="true" />
            <span className="min-w-0 flex-1 truncate">{option.label}</span>
            {selected ? <Check className="h-4 w-4 shrink-0" aria-hidden="true" /> : null}
          </label>
        );
      })}
    </div>
  );
}

export function WorkLogTimeChartDialog({
  open,
  tasks,
  items,
  taskTags = [],
  tagNames = {},
  onClose,
}: WorkLogTimeChartDialogProps) {
  const closeButtonRef = useRef<HTMLButtonElement | null>(null);
  const taskFilterRef = useRef<HTMLButtonElement | null>(null);
  const tagFilterRef = useRef<HTMLButtonElement | null>(null);
  const taskFilterPanelRef = useRef<HTMLDivElement | null>(null);
  const tagFilterPanelRef = useRef<HTMLDivElement | null>(null);

  const baseDataset = useMemo(
    () =>
      buildWorkLogTimeChartDataset({
        tasks,
        items,
        taskTags,
        tagNames,
        filters: {
          startDate: '',
          endDate: '',
          selectedTaskIds: [],
          selectedTagIds: [],
        },
      }),
    [items, tagNames, taskTags, tasks],
  );

  const [filters, setFilters] = useState<WorkLogTimeChartFilterState>(() =>
    buildDefaultWorkLogTimeChartFilters(baseDataset.availableRange),
  );
  const [openFilterPanel, setOpenFilterPanel] = useState<FilterPanelKind | null>(null);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [tooltip, setTooltip] = useState<TooltipState | null>(null);

  useEffect(() => {
    if (!open) {
      return;
    }
    setFilters(buildDefaultWorkLogTimeChartFilters(baseDataset.availableRange));
    setOpenFilterPanel(null);
    setIsFullscreen(false);
    setTooltip(null);
  }, [baseDataset.availableRange, open]);

  const dataset = useMemo(
    () =>
      buildWorkLogTimeChartDataset({
        tasks,
        items,
        taskTags,
        tagNames,
        filters,
      }),
    [filters, items, tagNames, taskTags, tasks],
  );

  useEffect(() => {
    if (!open) {
      return;
    }

    closeButtonRef.current?.focus();
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [open]);

  useEffect(() => {
    if (!open) {
      return;
    }

    const handleKeydown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        setOpenFilterPanel(null);
        setTooltip(null);
        if (isFullscreen) {
          setIsFullscreen(false);
          return;
        }
        onClose();
      }
    };

    window.addEventListener('keydown', handleKeydown);
    return () => window.removeEventListener('keydown', handleKeydown);
  }, [isFullscreen, onClose, open]);

  useEffect(() => {
    if (!open || openFilterPanel === null) {
      return;
    }

    const handlePointerDown = (event: MouseEvent) => {
      const target = event.target as Node;
      if (openFilterPanel === 'task') {
        if (taskFilterRef.current?.contains(target) || taskFilterPanelRef.current?.contains(target)) {
          return;
        }
      }
      if (openFilterPanel === 'tag') {
        if (tagFilterRef.current?.contains(target) || tagFilterPanelRef.current?.contains(target)) {
          return;
        }
      }
      setOpenFilterPanel(null);
    };

    window.addEventListener('mousedown', handlePointerDown);
    return () => window.removeEventListener('mousedown', handlePointerDown);
  }, [open, openFilterPanel]);

  if (!open || typeof document === 'undefined') {
    return null;
  }

  const taskFilterValues = baseDataset.taskOptions.map((option) => option.value);
  const tagFilterValues = baseDataset.tagOptions.map((option) => option.value);
  const showTooltip = (bar: WorkLogTimeChartBar, target: HTMLElement) => {
    const nextPosition = positionTooltip(target);
    setTooltip({
      bar,
      ...nextPosition,
    });
  };

  const dialogContent = (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center bg-slate-950/45 p-4 backdrop-blur-sm"
      onMouseDown={(event) => {
        if (event.target === event.currentTarget) {
          onClose();
        }
      }}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label="工时记录柱状图"
        data-fullscreen={isFullscreen ? 'true' : 'false'}
        className={cn(
          'relative z-50 flex max-h-[calc(100vh-2rem)] w-[min(96vw,1280px)] flex-col overflow-hidden rounded-[2rem] border border-white/70 bg-[linear-gradient(180deg,rgba(248,250,252,0.98),rgba(255,255,255,0.98))] shadow-[0_28px_100px_rgba(15,23,42,0.28)]',
          isFullscreen && 'h-[calc(100vh-2rem)] w-[calc(100vw-2rem)] max-w-none',
        )}
        onMouseDown={(event) => event.stopPropagation()}
      >
        <div className="border-b border-slate-200/80 bg-[radial-gradient(circle_at_top_right,_rgba(37,99,235,0.16),transparent_26%),linear-gradient(135deg,rgba(255,255,255,0.96),rgba(248,250,252,0.98))] px-6 py-5">
          <div className="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-2 text-xs font-semibold uppercase tracking-[0.22em] text-brand-700">
                <BarChart3 className="h-4 w-4" aria-hidden="true" />
                Time Analytics
              </div>
              <h2 className="mt-3 text-2xl font-semibold text-ink">工时走势柱状图</h2>
              <p className="mt-2 max-w-3xl text-sm leading-6 text-slate-600">
                按日期查看查询范围内的任务工时分布，多任务同日会并列展示。
              </p>
              <div className="mt-4 flex flex-wrap gap-2">
                <span className="rounded-full bg-white/90 px-3 py-1 text-xs font-medium text-slate-600 shadow-sm">
                  {formatNumber(dataset.totalMinutes)} 分钟
                </span>
                <span className="rounded-full bg-white/90 px-3 py-1 text-xs font-medium text-slate-600 shadow-sm">
                  {formatNumber(dataset.totalEntries)} 条记录
                </span>
                <span className="rounded-full bg-white/90 px-3 py-1 text-xs font-medium text-slate-600 shadow-sm">
                  {formatNumber(dataset.days.length)} 天
                </span>
              </div>
            </div>
            <div className="flex flex-wrap items-center gap-2">
              <button
                type="button"
                aria-label={isFullscreen ? '退出全屏' : '进入全屏'}
                onClick={() => setIsFullscreen((current) => !current)}
                className={`${DASHBOARD_PILL_BUTTON_SM} border border-slate-200 bg-white text-slate-700 hover:border-brand-200 hover:bg-brand-50`}
              >
                {isFullscreen ? <Minimize2 className="h-4 w-4" aria-hidden="true" /> : <Maximize2 className="h-4 w-4" aria-hidden="true" />}
                {isFullscreen ? '退出全屏' : '进入全屏'}
              </button>
              <button
                ref={closeButtonRef}
                type="button"
                aria-label="关闭工时柱状图"
                onClick={onClose}
                className={`${DASHBOARD_PILL_BUTTON_MD} bg-ink text-white hover:bg-slate-800`}
              >
                <X className="h-4 w-4" aria-hidden="true" />
                关闭
              </button>
            </div>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto px-6 py-5">
          <div className="rounded-[1.75rem] border border-slate-200/80 bg-slate-50/80 p-4">
            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
              <div className="grid gap-3 sm:grid-cols-2 lg:flex lg:flex-wrap lg:items-center">
                <label className="block space-y-1 text-sm text-slate-700">
                  <span className="inline-flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
                    <CalendarRange className="h-3.5 w-3.5" aria-hidden="true" />
                    时间范围
                  </span>
                  <input
                    aria-label="开始日期"
                    type="date"
                    value={filters.startDate}
                    onChange={(event) =>
                      setFilters((current) => ({
                        ...current,
                        startDate: event.target.value,
                      }))
                    }
                    className="h-11 min-w-[11rem] rounded-2xl border border-slate-200 bg-white px-4 text-sm outline-none transition focus:border-brand-400 focus:bg-white"
                  />
                </label>
                <label className="block space-y-1 text-sm text-slate-700">
                  <span className="text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">结束日期</span>
                  <input
                    aria-label="结束日期"
                    type="date"
                    value={filters.endDate}
                    onChange={(event) =>
                      setFilters((current) => ({
                        ...current,
                        endDate: event.target.value,
                      }))
                    }
                    className="h-11 min-w-[11rem] rounded-2xl border border-slate-200 bg-white px-4 text-sm outline-none transition focus:border-brand-400 focus:bg-white"
                  />
                </label>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <button
                  ref={taskFilterRef}
                  type="button"
                  aria-label="按任务筛选"
                  aria-expanded={openFilterPanel === 'task'}
                  onClick={() => setOpenFilterPanel((current) => (current === 'task' ? null : 'task'))}
                  className={`${DASHBOARD_PILL_BUTTON_SM} border border-slate-200 bg-white text-slate-700 hover:border-brand-200 hover:bg-brand-50`}
                >
                  <BriefcaseBusiness className="h-4 w-4" aria-hidden="true" />
                  {getFilterSummary(filters.selectedTaskIds, baseDataset.taskOptions, '全部任务')}
                  <ChevronDown className="h-4 w-4" aria-hidden="true" />
                </button>
                <button
                  ref={tagFilterRef}
                  type="button"
                  aria-label="按任务标签筛选"
                  aria-expanded={openFilterPanel === 'tag'}
                  onClick={() => setOpenFilterPanel((current) => (current === 'tag' ? null : 'tag'))}
                  className={`${DASHBOARD_PILL_BUTTON_SM} border border-slate-200 bg-white text-slate-700 hover:border-brand-200 hover:bg-brand-50`}
                >
                  <Tags className="h-4 w-4" aria-hidden="true" />
                  {getFilterSummary(filters.selectedTagIds, baseDataset.tagOptions, '全部标签')}
                  <ChevronDown className="h-4 w-4" aria-hidden="true" />
                </button>
                <button
                  type="button"
                  onClick={() => setFilters(buildDefaultWorkLogTimeChartFilters(baseDataset.availableRange))}
                  className={`${DASHBOARD_PILL_BUTTON_SM} border border-slate-200 bg-white text-slate-700 hover:border-brand-200 hover:bg-brand-50`}
                >
                  重置筛选
                </button>
              </div>
            </div>

            {openFilterPanel === 'task' ? (
              <div
                ref={taskFilterPanelRef}
                role="group"
                aria-label="工时图任务筛选面板"
                className="mt-4 rounded-3xl border border-slate-200 bg-white/90 p-4"
              >
                <FilterPanel
                  options={baseDataset.taskOptions}
                  selectedValues={filters.selectedTaskIds}
                  onToggle={(value) =>
                    setFilters((current) => ({
                      ...current,
                      selectedTaskIds: toggleFilterValue(current.selectedTaskIds, value, taskFilterValues),
                    }))
                  }
                />
              </div>
            ) : null}

            {openFilterPanel === 'tag' ? (
              <div
                ref={tagFilterPanelRef}
                role="group"
                aria-label="工时图标签筛选面板"
                className="mt-4 rounded-3xl border border-slate-200 bg-white/90 p-4"
              >
                <FilterPanel
                  options={baseDataset.tagOptions}
                  selectedValues={filters.selectedTagIds}
                  onToggle={(value) =>
                    setFilters((current) => ({
                      ...current,
                      selectedTagIds: toggleFilterValue(current.selectedTagIds, value, tagFilterValues),
                    }))
                  }
                />
              </div>
            ) : null}
          </div>

          <div className="mt-5 grid gap-5 xl:grid-cols-[minmax(0,1fr)_290px]">
            <section className="min-w-0 rounded-[1.75rem] border border-slate-200/80 bg-white/88 p-5 shadow-sm">
              <div className="flex flex-col gap-1 sm:flex-row sm:items-end sm:justify-between">
                <div>
                  <h3 className="text-lg font-semibold text-ink">按日并列柱状图</h3>
                  <p className="mt-1 text-sm text-slate-600">同一天内有多个任务时，会使用不同颜色并列展示。</p>
                </div>
                <p className="text-xs font-medium uppercase tracking-[0.18em] text-slate-500">
                  Max {formatNumber(dataset.maxMinutes)} min
                </p>
              </div>

              {dataset.days.length === 0 ? (
                <div className="mt-5 rounded-3xl border border-dashed border-slate-200 bg-slate-50 px-4 py-16 text-center text-sm text-slate-500">
                  当前筛选下暂无工时记录，可调整时间范围、任务或标签后重试。
                </div>
              ) : (
                <div className="mt-5 overflow-x-auto pb-2">
                  <div className="flex min-w-max gap-4">
                    {dataset.days.map((day) => (
                      <section
                        key={day.dateKey}
                        className="w-[11.5rem] shrink-0 rounded-[1.5rem] border border-slate-200/80 bg-[linear-gradient(180deg,rgba(248,250,252,0.95),rgba(255,255,255,0.95))] p-4"
                      >
                        <div className="flex items-start justify-between gap-3">
                          <div>
                            <p className="text-sm font-semibold text-ink">{day.dateLabel}</p>
                            <p className="mt-1 text-xs text-slate-500">{formatNumber(day.totalMinutes)} 分钟</p>
                          </div>
                          <div className="rounded-full bg-slate-100 px-2 py-1 text-[11px] font-medium text-slate-500">
                            {day.bars.length} 任务
                          </div>
                        </div>

                        <div className="mt-4 flex h-72 items-end gap-2 rounded-[1.25rem] border border-slate-200/80 bg-[linear-gradient(180deg,rgba(248,250,252,0.92),rgba(241,245,249,0.92))] p-3">
                          {day.bars.map((bar) => {
                            const heightRatio = dataset.maxMinutes > 0 ? bar.minutes / dataset.maxMinutes : 0;
                            const barHeight = Math.max(22, Math.round(heightRatio * 224));

                            return (
                              <button
                                key={bar.key}
                                type="button"
                                aria-label={`工时柱 ${bar.dateKey} ${bar.taskTitle} ${bar.minutes} 分钟`}
                                onMouseEnter={(event) => showTooltip(bar, event.currentTarget)}
                                onMouseLeave={() => setTooltip(null)}
                                onFocus={(event) => showTooltip(bar, event.currentTarget)}
                                onBlur={() => setTooltip(null)}
                                onClick={(event) => showTooltip(bar, event.currentTarget)}
                                className="flex min-w-0 flex-1 cursor-pointer flex-col justify-end rounded-[1.15rem] px-2 pb-3 pt-4 text-left text-white shadow-[0_12px_32px_rgba(15,23,42,0.22)] transition hover:-translate-y-1 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-500"
                                style={{
                                  height: `${barHeight}px`,
                                  background: `linear-gradient(180deg, ${bar.color}, rgba(15,23,42,0.92))`,
                                }}
                              >
                                <span className="text-xs font-semibold leading-5">{formatNumber(bar.minutes)}</span>
                                <span className="mt-1 text-[11px] leading-4 text-white/80">{bar.entryCount} 条</span>
                              </button>
                            );
                          })}
                        </div>
                      </section>
                    ))}
                  </div>
                </div>
              )}
            </section>

            <aside className="rounded-[1.75rem] border border-slate-200/80 bg-white/88 p-5 shadow-sm">
              <h3 className="text-lg font-semibold text-ink">图例</h3>
              <p className="mt-1 text-sm text-slate-600">颜色与任务保持一一对应，悬浮柱体可查看当天工时。</p>

              {dataset.legendItems.length === 0 ? (
                <div className="mt-5 rounded-3xl border border-dashed border-slate-200 bg-slate-50 px-4 py-10 text-center text-sm text-slate-500">
                  当前筛选下没有可展示的任务图例。
                </div>
              ) : (
                <div className="mt-5 space-y-3">
                  {dataset.legendItems.map((item) => (
                    <div
                      key={item.key}
                      className="flex items-center justify-between gap-3 rounded-2xl border border-slate-200 bg-slate-50/80 px-3 py-3"
                    >
                      <div className="flex min-w-0 items-center gap-3">
                        <span className="h-3.5 w-3.5 shrink-0 rounded-full" style={{ backgroundColor: item.color }} aria-hidden="true" />
                        <span className="truncate text-sm font-medium text-slate-700">{item.label}</span>
                      </div>
                      <span className="shrink-0 text-xs font-semibold text-slate-500">{formatNumber(item.totalMinutes)} 分钟</span>
                    </div>
                  ))}
                </div>
              )}
            </aside>
          </div>
        </div>

        {tooltip ? (
          <div
            role="tooltip"
            aria-label={`工时提示 ${tooltip.bar.dateKey} ${tooltip.bar.taskTitle}`}
            className="pointer-events-none fixed z-[60] w-60 rounded-2xl border border-slate-200/90 bg-white/96 p-4 shadow-[0_18px_40px_rgba(15,23,42,0.22)]"
            style={{
              top: `${tooltip.top}px`,
              left: `${tooltip.left}px`,
            }}
          >
            <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
              <span className="h-3 w-3 rounded-full" style={{ backgroundColor: tooltip.bar.color }} aria-hidden="true" />
              Hover Detail
            </div>
            <p className="mt-3 text-base font-semibold text-ink">{tooltip.bar.taskTitle}</p>
            <div className="mt-3 grid gap-2 text-sm text-slate-600">
              <div className="flex items-center justify-between gap-3">
                <span>日期</span>
                <span className="font-medium text-ink">{tooltip.bar.dateKey}</span>
              </div>
              <div className="flex items-center justify-between gap-3">
                <span>工时</span>
                <span className="font-medium text-ink">{formatNumber(tooltip.bar.minutes)} 分钟</span>
              </div>
              <div className="flex items-center justify-between gap-3">
                <span>记录数</span>
                <span className="font-medium text-ink">{formatNumber(tooltip.bar.entryCount)} 条</span>
              </div>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );

  return createPortal(dialogContent, document.body);
}
