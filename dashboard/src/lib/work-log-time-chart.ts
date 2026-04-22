import type { WorkLogRow } from '@/lib/work-log-tree';

export type { WorkLogRow } from '@/lib/work-log-tree';

export interface WorkLogTimeChartFilterState {
  startDate: string;
  endDate: string;
  selectedTaskIds: string[];
  selectedTagIds: string[];
}

export interface WorkLogTimeChartRange {
  startDate: string;
  endDate: string;
}

export interface WorkLogTimeChartTaskOption {
  value: string;
  label: string;
  color: string;
  totalMinutes: number;
  tagIds: string[];
}

export interface WorkLogTimeChartTagOption {
  value: string;
  label: string;
}

export interface WorkLogTimeChartBar {
  key: string;
  dateKey: string;
  taskKey: string;
  taskId: number | null;
  taskTitle: string;
  minutes: number;
  color: string;
  entryCount: number;
}

export interface WorkLogTimeChartDayGroup {
  dateKey: string;
  dateLabel: string;
  totalMinutes: number;
  bars: WorkLogTimeChartBar[];
}

export interface WorkLogTimeChartLegendItem {
  key: string;
  label: string;
  color: string;
  totalMinutes: number;
}

export interface WorkLogTimeChartDataset {
  days: WorkLogTimeChartDayGroup[];
  legendItems: WorkLogTimeChartLegendItem[];
  taskOptions: WorkLogTimeChartTaskOption[];
  tagOptions: WorkLogTimeChartTagOption[];
  totalMinutes: number;
  totalEntries: number;
  maxMinutes: number;
  availableRange: WorkLogTimeChartRange;
}

export const ORPHAN_WORK_LOG_TASK_LABEL = '未归属 / 异常归属';

const ORPHAN_TASK_KEY = 'orphan';
const ORPHAN_TASK_COLOR = '#64748B';
const CHART_COLOR_PALETTE = [
  '#2563EB',
  '#0F766E',
  '#F59E0B',
  '#DC2626',
  '#7C3AED',
  '#0891B2',
  '#EA580C',
  '#65A30D',
] as const;

interface BuildWorkLogTimeChartDatasetArgs {
  tasks: WorkLogRow[];
  items: WorkLogRow[];
  taskTags?: WorkLogRow[];
  tagNames?: Record<string, string>;
  filters: WorkLogTimeChartFilterState;
}

interface TaskMeta {
  id: number;
  label: string;
  order: number;
  tagIds: string[];
}

interface NormalizedEntry {
  id: string;
  taskKey: string;
  taskId: number | null;
  taskTitle: string;
  tagIds: string[];
  dateKey: string;
  minutes: number;
}

function toNumeric(value: unknown) {
  const numeric = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(numeric) ? numeric : null;
}

function toBoolean(value: unknown) {
  if (typeof value === 'boolean') {
    return value;
  }
  if (typeof value === 'number') {
    return value !== 0;
  }
  if (typeof value === 'string') {
    return value === 'true' || value === '1';
  }
  return false;
}

function formatDateKey(timestamp: number) {
  const date = new Date(timestamp);
  const year = String(date.getFullYear());
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function buildRange(dateKeys: string[]): WorkLogTimeChartRange {
  if (dateKeys.length === 0) {
    return {
      startDate: '',
      endDate: '',
    };
  }
  return {
    startDate: dateKeys[0],
    endDate: dateKeys[dateKeys.length - 1],
  };
}

function sortTasks(tasks: WorkLogRow[]) {
  return [...tasks].sort((left, right) => {
    const pinnedDiff = Number(toBoolean(right.is_pinned)) - Number(toBoolean(left.is_pinned));
    if (pinnedDiff !== 0) {
      return pinnedDiff;
    }

    const sortDiff =
      (toNumeric(left.sort_index) ?? Number.MAX_SAFE_INTEGER) -
      (toNumeric(right.sort_index) ?? Number.MAX_SAFE_INTEGER);
    if (sortDiff !== 0) {
      return sortDiff;
    }

    const idDiff =
      (toNumeric(left.id) ?? Number.MAX_SAFE_INTEGER) -
      (toNumeric(right.id) ?? Number.MAX_SAFE_INTEGER);
    if (idDiff !== 0) {
      return idDiff;
    }

    return String(left.title ?? '').localeCompare(String(right.title ?? ''), 'zh-CN');
  });
}

function buildTaskMetaMap(tasks: WorkLogRow[], taskTags: WorkLogRow[]) {
  const tagIdsByTaskId = taskTags.reduce<Map<number, string[]>>((result, relation) => {
    const taskId = toNumeric(relation.task_id);
    const tagId = toNumeric(relation.tag_id);
    if (taskId === null || tagId === null) {
      return result;
    }
    const current = result.get(taskId) ?? [];
    current.push(String(tagId));
    result.set(taskId, Array.from(new Set(current)));
    return result;
  }, new Map<number, string[]>());

  return sortTasks(tasks).reduce<Map<number, TaskMeta>>((result, task, index) => {
    const taskId = toNumeric(task.id);
    if (taskId === null) {
      return result;
    }
    result.set(taskId, {
      id: taskId,
      label: String(task.title ?? `任务#${taskId}`),
      order: index,
      tagIds: tagIdsByTaskId.get(taskId) ?? [],
    });
    return result;
  }, new Map<number, TaskMeta>());
}

function normalizeDateRange(filters: WorkLogTimeChartFilterState) {
  if (!filters.startDate || !filters.endDate) {
    return {
      startDate: filters.startDate,
      endDate: filters.endDate,
    };
  }

  return filters.startDate <= filters.endDate
    ? { startDate: filters.startDate, endDate: filters.endDate }
    : { startDate: filters.endDate, endDate: filters.startDate };
}

export function buildDefaultWorkLogTimeChartFilters(
  availableRange: WorkLogTimeChartRange,
): WorkLogTimeChartFilterState {
  return {
    startDate: availableRange.startDate,
    endDate: availableRange.endDate,
    selectedTaskIds: [],
    selectedTagIds: [],
  };
}

export function buildWorkLogTimeChartDataset({
  tasks,
  items,
  taskTags = [],
  tagNames = {},
  filters,
}: BuildWorkLogTimeChartDatasetArgs): WorkLogTimeChartDataset {
  const taskMetaMap = buildTaskMetaMap(tasks, taskTags);
  const entryTaskIds = new Set<number>();

  for (const item of items) {
    const taskId = toNumeric(item.task_id);
    if (taskId !== null && taskMetaMap.has(taskId)) {
      entryTaskIds.add(taskId);
    }
  }

  const orderedTaskMetas = [...taskMetaMap.values()].filter((task) => entryTaskIds.has(task.id));
  const colorByTaskKey = new Map<string, string>();
  for (const task of orderedTaskMetas) {
    colorByTaskKey.set(String(task.id), CHART_COLOR_PALETTE[task.order % CHART_COLOR_PALETTE.length]);
  }

  const normalizedEntries = items.reduce<NormalizedEntry[]>((result, item, index) => {
    const minutes = toNumeric(item.minutes);
    const timestamp = toNumeric(item.work_date) ?? toNumeric(item.created_at);
    if (minutes === null || minutes <= 0 || timestamp === null || timestamp <= 0) {
      return result;
    }

    const taskId = toNumeric(item.task_id);
    const taskMeta = taskId === null ? null : taskMetaMap.get(taskId) ?? null;
    result.push({
      id: String(item.id ?? index),
      taskKey: taskMeta ? String(taskMeta.id) : ORPHAN_TASK_KEY,
      taskId: taskMeta?.id ?? null,
      taskTitle: taskMeta?.label ?? ORPHAN_WORK_LOG_TASK_LABEL,
      tagIds: taskMeta?.tagIds ?? [],
      dateKey: formatDateKey(timestamp),
      minutes,
    });
    return result;
  }, []);

  const availableDateKeys = Array.from(new Set(normalizedEntries.map((entry) => entry.dateKey))).sort((left, right) =>
    left.localeCompare(right),
  );
  const availableRange = buildRange(availableDateKeys);
  const { startDate, endDate } = normalizeDateRange(filters);
  const selectedTaskIds = new Set(filters.selectedTaskIds);
  const selectedTagIds = new Set(filters.selectedTagIds);

  const filteredEntries = normalizedEntries.filter((entry) => {
    if (startDate && entry.dateKey < startDate) {
      return false;
    }
    if (endDate && entry.dateKey > endDate) {
      return false;
    }
    if (selectedTaskIds.size > 0 && (entry.taskId === null || !selectedTaskIds.has(String(entry.taskId)))) {
      return false;
    }
    if (selectedTagIds.size > 0 && !entry.tagIds.some((tagId) => selectedTagIds.has(tagId))) {
      return false;
    }
    return true;
  });

  const totalMinutes = filteredEntries.reduce((sum, entry) => sum + entry.minutes, 0);
  const dayOrder = Array.from(new Set(filteredEntries.map((entry) => entry.dateKey))).sort((left, right) =>
    left.localeCompare(right),
  );
  const taskOrder = new Map<string, number>();
  for (const task of orderedTaskMetas) {
    taskOrder.set(String(task.id), task.order);
  }
  taskOrder.set(ORPHAN_TASK_KEY, Number.MAX_SAFE_INTEGER);

  const dayBuckets = new Map<string, Map<string, WorkLogTimeChartBar>>();
  for (const entry of filteredEntries) {
    const taskBucket = dayBuckets.get(entry.dateKey) ?? new Map<string, WorkLogTimeChartBar>();
    const current = taskBucket.get(entry.taskKey);
    const nextBar =
      current ??
      ({
        key: `${entry.dateKey}:${entry.taskKey}`,
        dateKey: entry.dateKey,
        taskKey: entry.taskKey,
        taskId: entry.taskId,
        taskTitle: entry.taskTitle,
        minutes: 0,
        color: colorByTaskKey.get(entry.taskKey) ?? ORPHAN_TASK_COLOR,
        entryCount: 0,
      } satisfies WorkLogTimeChartBar);

    nextBar.minutes += entry.minutes;
    nextBar.entryCount += 1;
    taskBucket.set(entry.taskKey, nextBar);
    dayBuckets.set(entry.dateKey, taskBucket);
  }

  const days = dayOrder.map((dateKey) => {
    const bars = Array.from(dayBuckets.get(dateKey)?.values() ?? []).sort((left, right) => {
      const orderDiff = (taskOrder.get(left.taskKey) ?? Number.MAX_SAFE_INTEGER) -
        (taskOrder.get(right.taskKey) ?? Number.MAX_SAFE_INTEGER);
      if (orderDiff !== 0) {
        return orderDiff;
      }
      return left.taskTitle.localeCompare(right.taskTitle, 'zh-CN');
    });
    return {
      dateKey,
      dateLabel: dateKey,
      totalMinutes: bars.reduce((sum, bar) => sum + bar.minutes, 0),
      bars,
    } satisfies WorkLogTimeChartDayGroup;
  });

  const legendBuckets = filteredEntries.reduce<Map<string, WorkLogTimeChartLegendItem>>((result, entry) => {
    const current = result.get(entry.taskKey);
    const nextLegend =
      current ??
      ({
        key: entry.taskKey,
        label: entry.taskTitle,
        color: colorByTaskKey.get(entry.taskKey) ?? ORPHAN_TASK_COLOR,
        totalMinutes: 0,
      } satisfies WorkLogTimeChartLegendItem);
    nextLegend.totalMinutes += entry.minutes;
    result.set(entry.taskKey, nextLegend);
    return result;
  }, new Map<string, WorkLogTimeChartLegendItem>());

  const legendItems = Array.from(legendBuckets.values()).sort((left, right) => {
    const orderDiff =
      (taskOrder.get(left.key) ?? Number.MAX_SAFE_INTEGER) -
      (taskOrder.get(right.key) ?? Number.MAX_SAFE_INTEGER);
    if (orderDiff !== 0) {
      return orderDiff;
    }
    return left.label.localeCompare(right.label, 'zh-CN');
  });

  const totalsByTaskId = normalizedEntries.reduce<Map<string, number>>((result, entry) => {
    if (entry.taskId === null) {
      return result;
    }
    const key = String(entry.taskId);
    result.set(key, (result.get(key) ?? 0) + entry.minutes);
    return result;
  }, new Map<string, number>());

  const taskOptions = orderedTaskMetas.map((task) => ({
    value: String(task.id),
    label: task.label,
    color: colorByTaskKey.get(String(task.id)) ?? ORPHAN_TASK_COLOR,
    totalMinutes: totalsByTaskId.get(String(task.id)) ?? 0,
    tagIds: task.tagIds,
  }));

  const tagOptions = Array.from(
    taskOptions.reduce<Map<string, string>>((result, task) => {
      for (const tagId of task.tagIds) {
        result.set(tagId, tagNames[tagId] ?? `标签#${tagId}`);
      }
      return result;
    }, new Map<string, string>()),
  )
    .map(([value, label]) => ({ value, label }))
    .sort((left, right) => left.label.localeCompare(right.label, 'zh-CN'));

  const maxMinutes = days.reduce((max, day) => {
    const dayMax = day.bars.reduce((current, bar) => Math.max(current, bar.minutes), 0);
    return Math.max(max, dayMax);
  }, 0);

  return {
    days,
    legendItems,
    taskOptions,
    tagOptions,
    totalMinutes,
    totalEntries: filteredEntries.length,
    maxMinutes,
    availableRange,
  };
}
