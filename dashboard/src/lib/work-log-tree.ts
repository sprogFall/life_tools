export type WorkLogRow = Record<string, unknown>;

export interface WorkLogTreeGroup {
  id: string;
  title: string;
  taskId: number | null;
  task: WorkLogRow | null;
  entries: WorkLogRow[];
  entryCount: number;
  totalMinutes: number;
  isOrphan: boolean;
}

function toNumber(value: unknown) {
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

function getTotalMinutes(entries: WorkLogRow[]) {
  return entries.reduce((total, entry) => total + (toNumber(entry.minutes) ?? 0), 0);
}

function sortTasks(tasks: WorkLogRow[]) {
  return [...tasks].sort((left, right) => {
    const pinnedDiff = Number(toBoolean(right.is_pinned)) - Number(toBoolean(left.is_pinned));
    if (pinnedDiff !== 0) {
      return pinnedDiff;
    }

    const sortDiff = (toNumber(left.sort_index) ?? Number.MAX_SAFE_INTEGER) - (toNumber(right.sort_index) ?? Number.MAX_SAFE_INTEGER);
    if (sortDiff !== 0) {
      return sortDiff;
    }

    return (toNumber(left.id) ?? Number.MAX_SAFE_INTEGER) - (toNumber(right.id) ?? Number.MAX_SAFE_INTEGER);
  });
}

export function buildWorkLogTree(tasks: WorkLogRow[], timeEntries: WorkLogRow[]): WorkLogTreeGroup[] {
  const sortedTasks = sortTasks(tasks);
  const entriesByTaskId = new Map<number, WorkLogRow[]>();
  const orphanEntries: WorkLogRow[] = [];
  const validTaskIds = new Set<number>();

  for (const task of sortedTasks) {
    const taskId = toNumber(task.id);
    if (taskId !== null) {
      validTaskIds.add(taskId);
    }
  }

  for (const entry of timeEntries) {
    const taskId = toNumber(entry.task_id);
    if (taskId === null || !validTaskIds.has(taskId)) {
      orphanEntries.push(entry);
      continue;
    }
    const current = entriesByTaskId.get(taskId) ?? [];
    current.push(entry);
    entriesByTaskId.set(taskId, current);
  }

  const taskGroups = sortedTasks.map((task) => {
    const taskId = toNumber(task.id);
    const entries = taskId === null ? [] : entriesByTaskId.get(taskId) ?? [];
    return {
      id: `task-${taskId ?? 'unknown'}`,
      title: String(task.title ?? `任务#${taskId ?? 'unknown'}`),
      taskId,
      task,
      entries,
      entryCount: entries.length,
      totalMinutes: getTotalMinutes(entries),
      isOrphan: false,
    } satisfies WorkLogTreeGroup;
  });

  return [
    ...taskGroups,
    {
      id: 'task-orphan',
      title: '未归属 / 异常归属',
      taskId: null,
      task: null,
      entries: orphanEntries,
      entryCount: orphanEntries.length,
      totalMinutes: getTotalMinutes(orphanEntries),
      isOrphan: true,
    },
  ];
}

export function reassignTimeEntryTask(
  timeEntries: WorkLogRow[],
  entryId: number,
  nextTaskId: number | null,
  now = Date.now(),
) {
  return timeEntries.map((entry) => {
    const currentId = toNumber(entry.id);
    if (currentId !== entryId) {
      return entry;
    }
    return {
      ...entry,
      task_id: nextTaskId,
      updated_at: now,
    } satisfies WorkLogRow;
  });
}
