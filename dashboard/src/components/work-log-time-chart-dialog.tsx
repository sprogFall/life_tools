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
  RotateCcw,
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
  type WorkLogTimeChartDayGroup,
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

interface ChartTick {
  value: number;
  ratio: number;
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
  const left = Math.max(24, Math.min(rect.left + rect.width / 2 - 124, window.innerWidth - 272));
  const top = Math.max(24, rect.top - 104);
  return { left, top };
}

function toRgba(hex: string, alpha: number) {
  const normalized = hex.replace('#', '');
  if (!/^[\da-fA-F]{6}$/.test(normalized)) {
    return hex;
  }

  const red = Number.parseInt(normalized.slice(0, 2), 16);
  const green = Number.parseInt(normalized.slice(2, 4), 16);
  const blue = Number.parseInt(normalized.slice(4, 6), 16);

  return `rgba(${red}, ${green}, ${blue}, ${alpha})`;
}

function getNiceMax(value: number) {
  if (value <= 0) {
    return 100;
  }

  const exponent = Math.floor(Math.log10(value));
  const magnitude = 10 ** exponent;
  const normalized = value / magnitude;

  let niceBase = 1;
  if (normalized <= 1) {
    niceBase = 1;
  } else if (normalized <= 2) {
    niceBase = 2;
  } else if (normalized <= 2.5) {
    niceBase = 2.5;
  } else if (normalized <= 5) {
    niceBase = 5;
  } else {
    niceBase = 10;
  }

  return niceBase * magnitude;
}

function buildChartTicks(maxValue: number) {
  const safeMax = getNiceMax(Math.max(maxValue * 1.12, 1));
  const stepCount = 5;
  const step = safeMax / stepCount;

  return Array.from({ length: stepCount + 1 }, (_, index) => {
    const value = step * (stepCount - index);
    return {
      value,
      ratio: value / safeMax,
    } satisfies ChartTick;
  });
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
      <div className="rounded-[1.35rem] bg-slate-50/90 px-4 py-4 text-sm text-slate-500">
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
              'flex cursor-pointer items-center gap-3 rounded-full px-4 py-3 text-sm transition',
              selected
                ? 'bg-[#2f6594] text-white shadow-[0_16px_28px_rgba(47,101,148,0.18)]'
                : 'bg-slate-100/85 text-slate-700 hover:bg-slate-200/85',
            )}
          >
            <input
              type="checkbox"
              className="sr-only"
              checked={selected}
              onChange={() => onToggle(option.value)}
            />
            <span
              className="h-3.5 w-3.5 shrink-0 rounded-full"
              style={{ backgroundColor: swatch }}
              aria-hidden="true"
            />
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
  const [hiddenLegendKeys, setHiddenLegendKeys] = useState<string[]>([]);
  const [tooltip, setTooltip] = useState<TooltipState | null>(null);

  useEffect(() => {
    if (!open) {
      return;
    }

    setFilters(buildDefaultWorkLogTimeChartFilters(baseDataset.availableRange));
    setOpenFilterPanel(null);
    setIsFullscreen(false);
    setHiddenLegendKeys([]);
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

  useEffect(() => {
    setHiddenLegendKeys((current) =>
      current.filter((key) => dataset.legendItems.some((item) => item.key === key)),
    );
  }, [dataset.legendItems]);

  useEffect(() => {
    setTooltip(null);
  }, [filters, hiddenLegendKeys]);

  if (!open || typeof document === 'undefined') {
    return null;
  }

  const taskFilterValues = baseDataset.taskOptions.map((option) => option.value);
  const tagFilterValues = baseDataset.tagOptions.map((option) => option.value);
  const visibleLegendKeySet = new Set(
    dataset.legendItems
      .filter((item) => !hiddenLegendKeys.includes(item.key))
      .map((item) => item.key),
  );
  const visibleDays = dataset.days.map((day) => ({
    ...day,
    bars: day.bars.filter((bar) => visibleLegendKeySet.has(bar.taskKey)),
  })) satisfies WorkLogTimeChartDayGroup[];
  const visibleMaxMinutes = visibleDays.reduce((max, day) => {
    const dayMax = day.bars.reduce((current, bar) => Math.max(current, bar.minutes), 0);
    return Math.max(max, dayMax);
  }, 0);
  const chartTicks = buildChartTicks(visibleMaxMinutes);
  const chartMax = chartTicks[0]?.value ?? 100;
  const hasVisibleBars = visibleDays.some((day) => day.bars.length > 0);
  const plotHeight = isFullscreen ? 520 : 420;
  const chartMinWidth = Math.max(visibleDays.length * 156, 720);
  const showTooltip = (bar: WorkLogTimeChartBar, target: HTMLElement) => {
    const nextPosition = positionTooltip(target);
    setTooltip({
      bar,
      ...nextPosition,
    });
  };

  const dialogContent = (
    <div
      className="fixed inset-0 z-40 flex items-center justify-center bg-[radial-gradient(circle_at_top,_rgba(59,130,246,0.12),transparent_24%),rgba(15,23,42,0.32)] p-4 backdrop-blur-[6px]"
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
          'relative z-50 flex max-h-[calc(100vh-2rem)] w-[min(96vw,1320px)] flex-col overflow-hidden rounded-[2.25rem] bg-[linear-gradient(180deg,#f8fbff,#f3f7fc)] shadow-[0_30px_90px_rgba(72,106,149,0.24)] ring-1 ring-white/80',
          isFullscreen && 'h-[calc(100vh-2rem)] w-[calc(100vw-2rem)] max-w-none',
        )}
        onMouseDown={(event) => event.stopPropagation()}
      >
        <div className="px-6 py-6 sm:px-8 sm:py-8 lg:px-10 lg:py-9">
          <div className="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
            <div className="flex min-w-0 items-start gap-4 sm:gap-5">
              <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-[1.05rem] bg-[#24324b] text-white shadow-[0_18px_32px_rgba(36,50,75,0.18)]">
                <BarChart3 className="h-7 w-7" aria-hidden="true" />
              </div>
              <div className="min-w-0">
                <h2 className="text-[clamp(2.1rem,3vw,3rem)] font-semibold tracking-[-0.04em] text-slate-800">
                  工时分组柱状图
                </h2>
                <p className="mt-3 text-base leading-7 text-slate-500 sm:text-lg">
                  按日期对比查询范围内的任务工时，点击图例可切换显示系列。
                </p>
                <p className="mt-3 text-sm font-medium text-slate-400">
                  {formatNumber(dataset.days.length)} 天 · {formatNumber(dataset.totalEntries)} 条记录 ·{' '}
                  {formatNumber(dataset.totalMinutes)} 分钟
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2 self-end lg:self-start">
              <button
                type="button"
                aria-label={isFullscreen ? '退出全屏' : '进入全屏'}
                onClick={() => setIsFullscreen((current) => !current)}
                className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-white/88 text-slate-600 shadow-[0_12px_24px_rgba(148,163,184,0.18)] transition hover:bg-white hover:text-slate-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-500"
              >
                {isFullscreen ? <Minimize2 className="h-5 w-5" aria-hidden="true" /> : <Maximize2 className="h-5 w-5" aria-hidden="true" />}
              </button>
              <button
                ref={closeButtonRef}
                type="button"
                aria-label="关闭工时柱状图"
                onClick={onClose}
                className="inline-flex h-12 w-12 items-center justify-center rounded-full bg-white/88 text-slate-600 shadow-[0_12px_24px_rgba(148,163,184,0.18)] transition hover:bg-white hover:text-slate-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-500"
              >
                <X className="h-5 w-5" aria-hidden="true" />
              </button>
            </div>
          </div>

          <div className="mt-6 flex flex-wrap items-center gap-3">
            <div className="flex flex-wrap items-center gap-2 rounded-full bg-slate-100/90 px-4 py-2 shadow-[0_12px_24px_rgba(148,163,184,0.12)]">
              <CalendarRange className="h-4 w-4 text-slate-500" aria-hidden="true" />
              <span className="text-sm font-medium text-slate-600">时间范围</span>
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
                className="h-10 min-w-[10.5rem] rounded-full border border-slate-200 bg-white px-4 text-sm text-slate-700 outline-none transition focus:border-brand-400"
              />
              <span className="text-sm text-slate-400">至</span>
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
                className="h-10 min-w-[10.5rem] rounded-full border border-slate-200 bg-white px-4 text-sm text-slate-700 outline-none transition focus:border-brand-400"
              />
            </div>

            <button
              ref={taskFilterRef}
              type="button"
              aria-label="按任务筛选"
              aria-expanded={openFilterPanel === 'task'}
              onClick={() => setOpenFilterPanel((current) => (current === 'task' ? null : 'task'))}
              className={`${DASHBOARD_PILL_BUTTON_MD} bg-slate-100/95 text-slate-700 shadow-[0_12px_24px_rgba(148,163,184,0.12)] hover:bg-slate-200/90`}
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
              className={`${DASHBOARD_PILL_BUTTON_MD} bg-slate-100/95 text-slate-700 shadow-[0_12px_24px_rgba(148,163,184,0.12)] hover:bg-slate-200/90`}
            >
              <Tags className="h-4 w-4" aria-hidden="true" />
              {getFilterSummary(filters.selectedTagIds, baseDataset.tagOptions, '全部标签')}
              <ChevronDown className="h-4 w-4" aria-hidden="true" />
            </button>

            <button
              type="button"
              onClick={() => {
                setFilters(buildDefaultWorkLogTimeChartFilters(baseDataset.availableRange));
                setHiddenLegendKeys([]);
              }}
              className={`${DASHBOARD_PILL_BUTTON_MD} bg-[#2f6594] text-white shadow-[0_18px_36px_rgba(47,101,148,0.24)] hover:bg-[#25557d]`}
            >
              <RotateCcw className="h-4 w-4" aria-hidden="true" />
              重置显示
            </button>
          </div>

          {openFilterPanel === 'task' ? (
            <div
              ref={taskFilterPanelRef}
              role="group"
              aria-label="工时图任务筛选面板"
              className="mt-4 rounded-[1.6rem] bg-white/82 p-4 shadow-[0_16px_40px_rgba(148,163,184,0.16)]"
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
              className="mt-4 rounded-[1.6rem] bg-white/82 p-4 shadow-[0_16px_40px_rgba(148,163,184,0.16)]"
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

        <div className="border-t border-slate-200/75" />

        <div className="flex-1 overflow-y-auto px-6 pb-6 pt-6 sm:px-8 lg:px-10 lg:pb-8">
          <div className="grid gap-4 lg:grid-cols-[1fr_auto_1fr] lg:items-center">
            <div className="hidden lg:block" />
            <div
              role="group"
              aria-label="分组柱状图图例"
              className="flex flex-wrap items-center justify-center gap-x-5 gap-y-3"
            >
              {dataset.legendItems.map((item) => {
                const visible = !hiddenLegendKeys.includes(item.key);
                return (
                  <button
                    key={item.key}
                    type="button"
                    aria-label={`切换图例 ${item.label}`}
                    aria-pressed={visible}
                    onClick={() =>
                      setHiddenLegendKeys((current) =>
                        current.includes(item.key)
                          ? current.filter((key) => key !== item.key)
                          : [...current, item.key],
                      )
                    }
                    className={cn(
                      'inline-flex items-center gap-3 rounded-full px-3 py-2 text-base transition',
                      visible ? 'text-slate-700 hover:bg-white/70' : 'text-slate-400 hover:bg-white/60',
                    )}
                  >
                    <span
                      className="h-4 w-4 shrink-0 rounded-full"
                      style={{
                        backgroundColor: visible ? item.color : toRgba(item.color, 0.35),
                      }}
                      aria-hidden="true"
                    />
                    <span className={cn('font-medium', !visible && 'line-through')}>{item.label}</span>
                  </button>
                );
              })}
            </div>
            <div className="flex items-center justify-start gap-2 lg:justify-end">
              <button
                type="button"
                aria-label="重置图例显示"
                disabled={hiddenLegendKeys.length === 0}
                onClick={() => setHiddenLegendKeys([])}
                className="inline-flex h-11 w-11 items-center justify-center rounded-full bg-white/88 text-slate-500 shadow-[0_12px_24px_rgba(148,163,184,0.18)] transition hover:bg-white hover:text-slate-700 disabled:cursor-not-allowed disabled:opacity-45"
              >
                <RotateCcw className="h-5 w-5" aria-hidden="true" />
              </button>
            </div>
          </div>

          <section
            role="group"
            aria-label="工时分组柱状图画布"
            className="mt-6 rounded-[2rem] bg-white/78 px-4 py-6 shadow-[inset_0_1px_0_rgba(255,255,255,0.72),0_18px_45px_rgba(148,163,184,0.14)] sm:px-6 lg:px-8"
          >
            {dataset.days.length === 0 ? (
              <div className="flex min-h-[26rem] items-center justify-center rounded-[1.6rem] bg-slate-50/85 px-6 text-center text-sm text-slate-500">
                当前筛选下暂无工时记录，可调整时间范围、任务或标签后重试。
              </div>
            ) : !hasVisibleBars ? (
              <div className="flex min-h-[26rem] items-center justify-center rounded-[1.6rem] bg-slate-50/85 px-6 text-center text-sm text-slate-500">
                当前已隐藏所有图例系列，可点击上方图例或右侧重置按钮恢复显示。
              </div>
            ) : (
              <div className="overflow-x-auto pb-2">
                <div
                  className="grid gap-4"
                  style={{
                    minWidth: `${chartMinWidth}px`,
                    gridTemplateColumns: '84px minmax(0, 1fr)',
                  }}
                >
                  <div className="relative" style={{ height: `${plotHeight}px` }}>
                    <div className="text-sm font-medium tracking-[0.01em] text-slate-600">工时（分钟）</div>
                    {chartTicks.map((tick) => (
                      <span
                        key={`tick-${tick.value}`}
                        className="absolute left-0 -translate-y-1/2 text-sm font-medium text-slate-400"
                        style={{ bottom: `${tick.ratio * 100}%` }}
                      >
                        {formatNumber(tick.value)}
                      </span>
                    ))}
                  </div>

                  <div>
                    <div className="relative" style={{ height: `${plotHeight}px` }}>
                      {chartTicks.map((tick) => (
                        <div
                          key={`grid-${tick.value}`}
                          className="absolute inset-x-0 border-t border-dashed border-[#d9e2ee]"
                          style={{ bottom: `${tick.ratio * 100}%` }}
                        />
                      ))}

                      <div className="absolute inset-x-0 bottom-0 border-t-2 border-slate-300/90" />

                      <div className="absolute inset-0 flex items-end">
                        {visibleDays.map((day) => (
                          <div key={day.dateKey} className="flex flex-1 items-end justify-center px-3">
                            <div className="flex h-full w-full max-w-[11rem] items-end justify-center gap-2 sm:gap-3">
                              {day.bars.map((bar) => {
                                const barHeight = Math.max(
                                  52,
                                  Math.round((bar.minutes / chartMax) * (plotHeight - 92)),
                                );

                                return (
                                  <div
                                    key={bar.key}
                                    className="flex min-w-0 flex-1 flex-col items-center justify-end gap-3"
                                  >
                                    <span className="rounded-full bg-white/96 px-3 py-1 text-sm font-semibold text-slate-700 shadow-[0_10px_24px_rgba(148,163,184,0.18)] ring-1 ring-slate-200/75">
                                      {formatNumber(bar.minutes)}
                                    </span>
                                    <button
                                      type="button"
                                      aria-label={`工时柱 ${bar.dateKey} ${bar.taskTitle} ${bar.minutes} 分钟`}
                                      onMouseEnter={(event) => showTooltip(bar, event.currentTarget)}
                                      onMouseLeave={() => setTooltip(null)}
                                      onFocus={(event) => showTooltip(bar, event.currentTarget)}
                                      onBlur={() => setTooltip(null)}
                                      onClick={(event) => showTooltip(bar, event.currentTarget)}
                                      className="w-full rounded-t-[1.05rem] rounded-b-[0.9rem] transition duration-300 hover:-translate-y-1 hover:brightness-[1.03] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand-500"
                                      style={{
                                        height: `${barHeight}px`,
                                        background: `linear-gradient(180deg, ${toRgba(bar.color, 0.88)} 0%, ${bar.color} 74%)`,
                                        boxShadow: `0 16px 28px ${toRgba(bar.color, 0.26)}`,
                                      }}
                                    />
                                  </div>
                                );
                              })}
                            </div>
                          </div>
                        ))}
                      </div>
                    </div>

                    <div className="mt-5 flex">
                      {visibleDays.map((day) => (
                        <div key={`label-${day.dateKey}`} className="flex-1 px-3 text-center">
                          <div className="mx-auto max-w-[11rem] text-base font-medium tracking-[0.01em] text-slate-600">
                            {day.dateLabel}
                          </div>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            )}
          </section>
        </div>

        {tooltip ? (
          <div
            role="tooltip"
            aria-label={`工时提示 ${tooltip.bar.dateKey} ${tooltip.bar.taskTitle}`}
            className="pointer-events-none fixed z-[60] w-64 rounded-[1.4rem] bg-white/97 p-4 shadow-[0_18px_40px_rgba(148,163,184,0.28)] ring-1 ring-slate-200/80"
            style={{
              top: `${tooltip.top}px`,
              left: `${tooltip.left}px`,
            }}
          >
            <div className="flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.18em] text-slate-500">
              <span
                className="h-3 w-3 rounded-full"
                style={{ backgroundColor: tooltip.bar.color }}
                aria-hidden="true"
              />
              Hover Detail
            </div>
            <p className="mt-3 text-base font-semibold text-slate-800">{tooltip.bar.taskTitle}</p>
            <div className="mt-3 grid gap-2 text-sm text-slate-600">
              <div className="flex items-center justify-between gap-3">
                <span>日期</span>
                <span className="font-medium text-slate-800">{tooltip.bar.dateKey}</span>
              </div>
              <div className="flex items-center justify-between gap-3">
                <span>工时</span>
                <span className="font-medium text-slate-800">{formatNumber(tooltip.bar.minutes)} 分钟</span>
              </div>
              <div className="flex items-center justify-between gap-3">
                <span>记录数</span>
                <span className="font-medium text-slate-800">{formatNumber(tooltip.bar.entryCount)} 条</span>
              </div>
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );

  return createPortal(dialogContent, document.body);
}
