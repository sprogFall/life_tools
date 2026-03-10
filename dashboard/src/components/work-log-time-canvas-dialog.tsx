'use client';

import { useEffect, useMemo, useRef, useState, type MouseEvent as ReactMouseEvent } from 'react';
import { createPortal } from 'react-dom';

import {
  AlertTriangle,
  Clock3,
  GripVertical,
  ListTree,
  Maximize2,
  Minimize2,
  Minus,
  MoonStar,
  SunMedium,
  Move,
  Plus,
  RotateCcw,
  Search,
  Sparkles,
  X,
} from 'lucide-react';

import {
  DASHBOARD_PILL_BUTTON_MD,
  DASHBOARD_PILL_BUTTON_SM,
} from '@/lib/button-styles';
import { cn, formatNumber, formatTimestamp } from '@/lib/format';
import {
  buildWorkLogTree,
  reassignTimeEntryTask,
  type WorkLogRow,
  type WorkLogTreeGroup,
} from '@/lib/work-log-tree';

interface WorkLogTimeCanvasDialogProps {
  open: boolean;
  tasks: WorkLogRow[];
  items: WorkLogRow[];
  onClose: () => void;
  onCommit: (items: WorkLogRow[]) => void;
}

interface ReassignmentRecord {
  entryId: number;
  entryLabel: string;
  fromTaskId: number | null;
  fromTitle: string;
}

interface CanvasViewState {
  scale: number;
  offsetX: number;
  offsetY: number;
}

interface CanvasLayoutNode {
  group: WorkLogTreeGroup;
  x: number;
  y: number;
  width: number;
  height: number;
}

interface PanOrigin {
  startX: number;
  startY: number;
  baseOffsetX: number;
  baseOffsetY: number;
}

interface NodeDragOrigin {
  nodeId: string;
  startX: number;
  startY: number;
  baseX: number;
  baseY: number;
}

interface NodeResizeOrigin {
  nodeId: string;
  title: string;
  startX: number;
  startY: number;
  baseRenderedWidth: number;
  baseRenderedHeight: number;
  baseWidth: number;
  baseHeight: number;
}

interface CanvasNodePosition {
  x: number;
  y: number;
}

interface CanvasRenderNode extends CanvasLayoutNode {
  scale: number;
  scaledWidth: number;
  scaledHeight: number;
}

const ORPHAN_TASK_TITLE = '未归属 / 异常归属';
const DEFAULT_VIEW: CanvasViewState = {
  scale: 1,
  offsetX: 0,
  offsetY: 0,
};
const MIN_SCALE = 0.7;
const MAX_SCALE = 1.5;
const SCALE_STEP = 0.1;
const MIN_NODE_SCALE = 0.85;
const MAX_NODE_SCALE = 1.6;
const CANVAS_THEME_STORAGE_KEY = 'dashboard.work-log-canvas-theme';

type CanvasTheme = 'dark' | 'light';

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

function clampScale(scale: number) {
  return Math.min(MAX_SCALE, Math.max(MIN_SCALE, Number(scale.toFixed(2))));
}

function clampNodeScale(scale: number) {
  return Math.min(MAX_NODE_SCALE, Math.max(MIN_NODE_SCALE, Number(scale.toFixed(2))));
}

function getStoredCanvasTheme(): CanvasTheme {
  if (typeof window === 'undefined') {
    return 'dark';
  }

  const savedTheme = window.localStorage.getItem(CANVAS_THEME_STORAGE_KEY);
  return savedTheme === 'dark' || savedTheme === 'light' ? savedTheme : 'dark';
}

function buildCanvasLayout(groups: WorkLogTreeGroup[]): CanvasLayoutNode[] {
  return groups.map((group, index) => {
    const width = 320;
    const lane = group.isOrphan ? 2 : index % 2;
    const x = 96 + index * 356;
    const y = group.isOrphan ? 404 : lane === 0 ? 96 : 264;
    const height = 188 + Math.max(group.entries.length, 1) * 112;

    return {
      group,
      x,
      y,
      width,
      height,
    } satisfies CanvasLayoutNode;
  });
}

export function WorkLogTimeCanvasDialog({
  open,
  tasks,
  items,
  onClose,
  onCommit,
}: WorkLogTimeCanvasDialogProps) {
  const closeButtonRef = useRef<HTMLButtonElement | null>(null);
  const panOriginRef = useRef<PanOrigin | null>(null);
  const nodeDragOriginRef = useRef<NodeDragOrigin | null>(null);
  const nodeResizeOriginRef = useRef<NodeResizeOrigin | null>(null);
  const [query, setQuery] = useState('');
  const [draftItems, setDraftItems] = useState<WorkLogRow[]>(items);
  const [draggingEntryId, setDraggingEntryId] = useState<number | null>(null);
  const [activeDropTaskId, setActiveDropTaskId] = useState<number | 'orphan' | null>(null);
  const [statusMessage, setStatusMessage] = useState('');
  const [lastReassignment, setLastReassignment] = useState<ReassignmentRecord | null>(null);
  const [view, setView] = useState<CanvasViewState>(DEFAULT_VIEW);
  const [nodePositions, setNodePositions] = useState<Record<string, CanvasNodePosition>>({});
  const [nodeScales, setNodeScales] = useState<Record<string, number>>({});
  const [isPanning, setIsPanning] = useState(false);
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [canvasTheme, setCanvasTheme] = useState<CanvasTheme>(getStoredCanvasTheme);

  useEffect(() => {
    if (typeof window === 'undefined') {
      return;
    }

    window.localStorage.setItem(CANVAS_THEME_STORAGE_KEY, canvasTheme);
  }, [canvasTheme]);

  useEffect(() => {
    if (!open) {
      return;
    }
    setDraftItems(items);
    setQuery('');
    setDraggingEntryId(null);
    setActiveDropTaskId(null);
    setStatusMessage('');
    setLastReassignment(null);
    setView(DEFAULT_VIEW);
    setNodePositions({});
    setNodeScales({});
    setIsPanning(false);
    panOriginRef.current = null;
    nodeDragOriginRef.current = null;
    nodeResizeOriginRef.current = null;
  }, [items, open]);

  useEffect(() => {
    if (!open) {
      return;
    }

    closeButtonRef.current?.focus();

    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault();
        onClose();
      }
    };

    const handleMouseMove = (event: MouseEvent) => {
      const resizeOrigin = nodeResizeOriginRef.current;
      if (resizeOrigin) {
        const deltaX = (event.clientX - resizeOrigin.startX) / view.scale;
        const deltaY = (event.clientY - resizeOrigin.startY) / view.scale;
        const nextScale = clampNodeScale(
          Math.max(
            (resizeOrigin.baseRenderedWidth + deltaX) / resizeOrigin.baseWidth,
            (resizeOrigin.baseRenderedHeight + deltaY) / resizeOrigin.baseHeight,
          ),
        );
        setNodeScales((current) => ({
          ...current,
          [resizeOrigin.nodeId]: nextScale,
        }));
        setStatusMessage(`正在缩放“${resizeOrigin.title}”任务树 · ${Math.round(nextScale * 100)}%`);
        return;
      }

      const nodeOrigin = nodeDragOriginRef.current;
      if (nodeOrigin) {
        setNodePositions((current) => ({
          ...current,
          [nodeOrigin.nodeId]: {
            x: Math.round(nodeOrigin.baseX + (event.clientX - nodeOrigin.startX) / view.scale),
            y: Math.round(nodeOrigin.baseY + (event.clientY - nodeOrigin.startY) / view.scale),
          },
        }));
        return;
      }

      const origin = panOriginRef.current;
      if (!origin) {
        return;
      }
      setView((current) => ({
        ...current,
        offsetX: origin.baseOffsetX + event.clientX - origin.startX,
        offsetY: origin.baseOffsetY + event.clientY - origin.startY,
      }));
    };

    const handleMouseUp = () => {
      panOriginRef.current = null;
      nodeDragOriginRef.current = null;
      nodeResizeOriginRef.current = null;
      setIsPanning(false);
    };

    window.addEventListener('keydown', handleKeyDown);
    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseup', handleMouseUp);

    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener('keydown', handleKeyDown);
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseup', handleMouseUp);
    };
  }, [onClose, open, view.scale]);

  const entryIndexMap = useMemo(() => {
    const mapping = new Map<number, number>();
    draftItems.forEach((item, index) => {
      const entryId = toNumericId(item.id);
      if (entryId !== null) {
        mapping.set(entryId, index);
      }
    });
    return mapping;
  }, [draftItems]);

  const taskTitleMap = useMemo(() => {
    const mapping = new Map<number, string>();
    tasks.forEach((task) => {
      const taskId = toNumericId(task.id);
      if (taskId !== null) {
        mapping.set(taskId, String(task.title ?? `任务#${taskId}`));
      }
    });
    return mapping;
  }, [tasks]);

  const resolveTaskTitle = (taskId: number | null) => {
    if (taskId === null) {
      return ORPHAN_TASK_TITLE;
    }
    return taskTitleMap.get(taskId) ?? `任务#${taskId}`;
  };

  const groups = useMemo(() => {
    const keyword = query.trim().toLowerCase();
    const tree = buildWorkLogTree(tasks, draftItems);

    if (!keyword) {
      return tree;
    }

    return tree
      .map((group) => {
        const taskMatches = group.title.toLowerCase().includes(keyword);
        const entries = taskMatches
          ? group.entries
          : group.entries.filter((entry) => matchesKeyword(entry, keyword));
        if (!taskMatches && entries.length === 0) {
          return null;
        }
        return {
          ...group,
          entries,
          entryCount: entries.length,
          totalMinutes: entries.reduce((total, entry) => total + (toNumericId(entry.minutes) ?? 0), 0),
        } satisfies WorkLogTreeGroup;
      })
      .filter((group): group is WorkLogTreeGroup => group !== null);
  }, [draftItems, query, tasks]);

  const layoutNodes = useMemo<CanvasRenderNode[]>(
    () =>
      buildCanvasLayout(groups).map((node) => {
        const override = nodePositions[node.group.id];
        const scale = nodeScales[node.group.id] ?? 1;
        return {
          ...node,
          x: override?.x ?? node.x,
          y: override?.y ?? node.y,
          scale,
          scaledWidth: Math.round(node.width * scale),
          scaledHeight: Math.round(node.height * scale),
        };
      }),
    [groups, nodePositions, nodeScales],
  );
  const canvasWidth = useMemo(
    () => Math.max(1480, ...layoutNodes.map((node) => node.x + node.scaledWidth + 120)),
    [layoutNodes],
  );
  const canvasHeight = useMemo(
    () => Math.max(920, ...layoutNodes.map((node) => node.y + node.scaledHeight + 120)),
    [layoutNodes],
  );
  const hasDraftChanges = JSON.stringify(items) !== JSON.stringify(draftItems);
  const isLightTheme = canvasTheme === 'light';
  const viewSummary = `缩放 ${Math.round(view.scale * 100)}% · 偏移 X ${Math.round(view.offsetX)} · 偏移 Y ${Math.round(view.offsetY)}`;

  const clearDragState = () => {
    setDraggingEntryId(null);
    setActiveDropTaskId(null);
  };

  const moveEntryToTask = ({
    entryId,
    targetTaskId,
    targetTitle,
    status,
    remember = true,
  }: {
    entryId: number;
    targetTaskId: number | null;
    targetTitle?: string;
    status?: string;
    remember?: boolean;
  }) => {
    const currentIndex = entryIndexMap.get(entryId);
    if (currentIndex === undefined) {
      clearDragState();
      return false;
    }

    const currentEntry = draftItems[currentIndex];
    const currentTaskId = toNumericId(currentEntry.task_id);
    const entryLabel = getEntryLabel(currentEntry);
    const nextTitle = targetTitle ?? resolveTaskTitle(targetTaskId);

    if (currentTaskId === targetTaskId) {
      setStatusMessage(`“${entryLabel}”已经归属在“${nextTitle}”下`);
      clearDragState();
      return false;
    }

    const previousTitle = resolveTaskTitle(currentTaskId);
    const nextItems = reassignTimeEntryTask(draftItems, entryId, targetTaskId, Date.now());
    setDraftItems(nextItems);
    setStatusMessage(status ?? `已将“${entryLabel}”归属到“${nextTitle}”`);
    if (remember) {
      setLastReassignment({
        entryId,
        entryLabel,
        fromTaskId: currentTaskId,
        fromTitle: previousTitle,
      });
    } else {
      setLastReassignment(null);
    }
    clearDragState();
    return true;
  };

  const handleDrop = (targetTaskId: number | null, targetTitle: string) => {
    if (draggingEntryId === null) {
      return;
    }
    moveEntryToTask({
      entryId: draggingEntryId,
      targetTaskId,
      targetTitle,
    });
  };

  const undoLastReassignment = () => {
    if (!lastReassignment) {
      return;
    }
    const reverted = moveEntryToTask({
      entryId: lastReassignment.entryId,
      targetTaskId: lastReassignment.fromTaskId,
      targetTitle: lastReassignment.fromTitle,
      status: `已撤销“${lastReassignment.entryLabel}”的归属调整，恢复到“${lastReassignment.fromTitle}”`,
      remember: false,
    });
    if (!reverted) {
      setLastReassignment(null);
    }
  };

  const zoomIn = () => {
    setView((current) => ({
      ...current,
      scale: clampScale(current.scale + SCALE_STEP),
    }));
  };

  const zoomOut = () => {
    setView((current) => ({
      ...current,
      scale: clampScale(current.scale - SCALE_STEP),
    }));
  };

  const resetView = () => {
    setView(DEFAULT_VIEW);
    setIsPanning(false);
    panOriginRef.current = null;
  };

  const startNodeDrag = (event: ReactMouseEvent<HTMLButtonElement>, node: CanvasLayoutNode) => {
    event.preventDefault();
    event.stopPropagation();
    panOriginRef.current = null;
    nodeResizeOriginRef.current = null;
    setIsPanning(false);
    nodeDragOriginRef.current = {
      nodeId: node.group.id,
      startX: event.clientX,
      startY: event.clientY,
      baseX: node.x,
      baseY: node.y,
    };
    setStatusMessage(`正在调整“${node.group.title}”模块位置`);
  };

  const startNodeResize = (event: ReactMouseEvent<HTMLButtonElement>, node: CanvasRenderNode) => {
    event.preventDefault();
    event.stopPropagation();
    panOriginRef.current = null;
    nodeDragOriginRef.current = null;
    setIsPanning(false);
    nodeResizeOriginRef.current = {
      nodeId: node.group.id,
      title: node.group.title,
      startX: event.clientX,
      startY: event.clientY,
      baseRenderedWidth: node.width * node.scale,
      baseRenderedHeight: node.height * node.scale,
      baseWidth: node.width,
      baseHeight: node.height,
    };
    setStatusMessage(`拖拽“${node.group.title}”右下角圆角，可缩放当前任务树`);
  };

  if (!open) {
    return null;
  }

  if (typeof document === 'undefined') {
    return null;
  }

  const dialogContent = (
    <div
      data-dialog-overlay="true"
      className={cn(
        'fixed inset-0 z-[100] flex backdrop-blur-md transition-colors',
        isLightTheme ? 'bg-slate-900/40' : 'bg-slate-950/78',
        isFullscreen ? 'items-stretch justify-stretch p-0' : 'items-center justify-center p-4 md:p-6',
      )}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label="工时归属整理画布"
        data-fullscreen={isFullscreen ? 'true' : 'false'}
        data-theme={canvasTheme}
        className={cn(
          'flex min-h-0 w-full flex-col overflow-hidden shadow-[0_40px_120px_rgba(2,6,23,0.22)] transition-colors',
          isLightTheme ? 'bg-white text-slate-900' : 'bg-slate-950 text-slate-100',
          isFullscreen
            ? 'h-full max-w-none rounded-none border-0'
            : isLightTheme
              ? 'h-[min(92vh,960px)] max-w-[1600px] rounded-[2rem] border border-slate-200/90'
              : 'h-[min(92vh,960px)] max-w-[1600px] rounded-[2rem] border border-slate-800/80',
        )}
      >
        {!isFullscreen ? (
          <header
            className={cn(
              'px-6 py-5',
              isLightTheme
                ? 'border-b border-slate-200 bg-[radial-gradient(circle_at_top_left,_rgba(16,185,129,0.16),transparent_26%),linear-gradient(135deg,#ffffff,#eff6ff)]'
                : 'border-b border-slate-800/80 bg-[radial-gradient(circle_at_top_left,_rgba(34,197,94,0.18),transparent_26%),linear-gradient(135deg,rgba(15,23,42,0.98),rgba(2,6,23,0.96))]',
            )}
          >
            <div className="flex flex-wrap items-start justify-between gap-4">
              <div className="space-y-3">
                <div
                  className={cn(
                    'inline-flex items-center gap-2 rounded-full px-3 py-1 text-xs font-medium',
                    isLightTheme
                      ? 'border border-emerald-200 bg-emerald-50 text-emerald-700'
                      : 'border border-emerald-500/20 bg-emerald-500/10 text-emerald-300',
                  )}
                >
                  <Sparkles className="h-3.5 w-3.5" />
                  沉浸式工时归属整理
                </div>
                <div>
                  <h3 className={cn('text-2xl font-semibold tracking-tight', isLightTheme ? 'text-slate-900' : 'text-white')}>
                    工时归属整理画布
                  </h3>
                  <p className={cn('mt-2 max-w-3xl text-sm leading-6', isLightTheme ? 'text-slate-600' : 'text-slate-300')}>
                    像白板一样在画布中浏览任务与工时卡片，拖拽即可改归属；只有点击“保存调整”后，当前改动才会写回工作台草稿。
                  </p>
                </div>
                <div className={cn('flex flex-wrap gap-2 text-xs', isLightTheme ? 'text-slate-600' : 'text-slate-300')}>
                  <span
                    className={cn(
                      'rounded-full px-3 py-1',
                      isLightTheme ? 'border border-slate-200 bg-white text-slate-600 shadow-sm' : 'border border-slate-700 bg-slate-900/80',
                    )}
                  >
                    {tasks.length} 个任务节点
                  </span>
                  <span
                    className={cn(
                      'rounded-full px-3 py-1',
                      isLightTheme ? 'border border-slate-200 bg-white text-slate-600 shadow-sm' : 'border border-slate-700 bg-slate-900/80',
                    )}
                  >
                    {draftItems.length} 条工时记录
                  </span>
                  <span
                    className={cn(
                      'rounded-full px-3 py-1',
                      isLightTheme ? 'border border-slate-200 bg-white text-slate-600 shadow-sm' : 'border border-slate-700 bg-slate-900/80',
                    )}
                  >
                    拖动画布 + 缩放观察
                  </span>
                </div>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <button
                  type="button"
                  onClick={onClose}
                  className={cn(
                    DASHBOARD_PILL_BUTTON_SM,
                    isLightTheme
                      ? 'border border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-50'
                      : 'border border-slate-700 bg-slate-900/80 text-slate-200 hover:border-slate-500 hover:bg-slate-900',
                  )}
                >
                  取消调整
                </button>
                <button
                  type="button"
                  aria-label={isLightTheme ? '切换到深色模式' : '切换到浅色模式'}
                  onClick={() => setCanvasTheme((current) => (current === 'light' ? 'dark' : 'light'))}
                  className={cn(
                    DASHBOARD_PILL_BUTTON_SM,
                    isLightTheme
                      ? 'border border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-50'
                      : 'border border-slate-700 bg-slate-900/80 text-slate-200 hover:border-slate-500 hover:bg-slate-900',
                  )}
                >
                  {isLightTheme ? <MoonStar className="h-4 w-4" /> : <SunMedium className="h-4 w-4" />}
                  {isLightTheme ? '深色模式' : '浅色模式'}
                </button>
                <button
                  type="button"
                  aria-label={isFullscreen ? '退出全屏' : '进入全屏'}
                  onClick={() => setIsFullscreen((current) => !current)}
                  className={cn(
                    DASHBOARD_PILL_BUTTON_SM,
                    isLightTheme
                      ? 'border border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-50'
                      : 'border border-slate-700 bg-slate-900/80 text-slate-200 hover:border-slate-500 hover:bg-slate-900',
                  )}
                >
                  {isFullscreen ? <Minimize2 className="h-4 w-4" /> : <Maximize2 className="h-4 w-4" />}
                  {isFullscreen ? '退出全屏' : '进入全屏'}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    onCommit(draftItems);
                    onClose();
                  }}
                  disabled={!hasDraftChanges}
                  className={cn(
                    DASHBOARD_PILL_BUTTON_MD,
                    isLightTheme
                      ? 'bg-emerald-600 text-white hover:bg-emerald-500 disabled:bg-slate-200 disabled:text-slate-400'
                      : 'bg-emerald-500 text-slate-950 hover:bg-emerald-400 disabled:bg-slate-700 disabled:text-slate-400',
                    'disabled:cursor-not-allowed',
                  )}
                >
                  保存调整
                </button>
                <button
                  ref={closeButtonRef}
                  type="button"
                  aria-label="关闭工时归属画布"
                  onClick={onClose}
                  className={cn(
                    'inline-flex h-11 w-11 items-center justify-center rounded-full transition',
                    isLightTheme
                      ? 'border border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-50'
                      : 'border border-slate-700 bg-slate-900/80 text-slate-200 hover:border-slate-500 hover:bg-slate-900',
                  )}
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
            </div>
          </header>
        ) : null}

        <div
          className={cn(
            isFullscreen ? 'px-4 py-3' : 'px-6 py-4',
            isLightTheme ? 'border-b border-slate-200 bg-white/90' : 'border-b border-slate-800/80 bg-slate-950/90',
          )}
        >
          <div className={cn('flex items-center gap-3', isFullscreen ? 'overflow-x-auto' : 'flex-wrap justify-between')}>
            <div className={cn('flex items-center gap-2', isFullscreen ? 'min-w-max flex-nowrap' : 'flex-wrap')}>
              <label
                className={cn(
                  'flex min-w-0 items-center gap-2 rounded-full px-3 py-2 text-sm',
                  isLightTheme
                    ? 'border border-slate-200 bg-slate-50 text-slate-700'
                    : 'border border-slate-800 bg-slate-900/80 text-slate-300',
                )}
              >
                <Search className={cn('h-4 w-4', isLightTheme ? 'text-slate-400' : 'text-slate-500')} />
                <span className="sr-only">筛选任务或工时</span>
                <input
                  aria-label="筛选任务或工时"
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  placeholder="搜索任务名、工时内容或日期"
                  className={cn(
                    isFullscreen ? 'w-52 bg-transparent text-sm outline-none lg:w-64' : 'w-full bg-transparent text-sm outline-none sm:w-64',
                    isLightTheme ? 'text-slate-900 placeholder:text-slate-400' : 'text-slate-100 placeholder:text-slate-500',
                  )}
                />
              </label>
              {!isFullscreen ? (
                <div
                  className={cn(
                    'inline-flex items-center gap-2 rounded-full px-3 py-2 text-xs',
                    isLightTheme
                      ? 'border border-slate-200 bg-slate-50 text-slate-600'
                      : 'border border-slate-800 bg-slate-900/80 text-slate-300',
                  )}
                >
                  <Move className={cn('h-3.5 w-3.5', isLightTheme ? 'text-slate-400' : 'text-slate-500')} />
                  拖动画布空白区域可平移，拖节点上边框可移动，拖右下角圆角边框可缩放单棵任务树
                </div>
              ) : null}
            </div>
            <div className={cn('flex items-center gap-2', isFullscreen ? 'min-w-max flex-nowrap' : 'flex-wrap')}>
              <button
                type="button"
                aria-label="缩小视图"
                onClick={zoomOut}
                className={cn(
                  'inline-flex h-10 w-10 items-center justify-center rounded-full transition',
                  isLightTheme
                    ? 'border border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-50'
                    : 'border border-slate-800 bg-slate-900/80 text-slate-200 hover:border-slate-600 hover:bg-slate-900',
                )}
              >
                <Minus className="h-4 w-4" />
              </button>
              <button
                type="button"
                aria-label="放大视图"
                onClick={zoomIn}
                className={cn(
                  'inline-flex h-10 w-10 items-center justify-center rounded-full transition',
                  isLightTheme
                    ? 'border border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-50'
                    : 'border border-slate-800 bg-slate-900/80 text-slate-200 hover:border-slate-600 hover:bg-slate-900',
                )}
              >
                <Plus className="h-4 w-4" />
              </button>
              <button
                type="button"
                aria-label="重置视图"
                onClick={resetView}
                className={cn(
                  `${DASHBOARD_PILL_BUTTON_SM} px-3`,
                  isLightTheme
                    ? 'border border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-50'
                    : 'border border-slate-800 bg-slate-900/80 text-slate-200 hover:border-slate-600 hover:bg-slate-900',
                )}
              >
                <RotateCcw className="h-4 w-4" />
                重置视图
              </button>
              {lastReassignment ? (
                <button
                  type="button"
                  onClick={undoLastReassignment}
                  className={cn(
                    `${DASHBOARD_PILL_BUTTON_SM} px-3`,
                    isLightTheme
                      ? 'border border-emerald-200 bg-emerald-50 text-emerald-700 hover:border-emerald-300 hover:bg-emerald-100'
                      : 'border border-emerald-500/30 bg-emerald-500/10 text-emerald-300 hover:border-emerald-400/40 hover:bg-emerald-500/15',
                  )}
                >
                  <RotateCcw className="h-4 w-4" />
                  撤销上次调整
                </button>
              ) : null}
              {isFullscreen ? (
                <>
                  <button
                    type="button"
                    onClick={onClose}
                    className={cn(
                      DASHBOARD_PILL_BUTTON_SM,
                      isLightTheme
                        ? 'border border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-50'
                        : 'border border-slate-700 bg-slate-900/80 text-slate-200 hover:border-slate-500 hover:bg-slate-900',
                    )}
                  >
                    取消
                  </button>
                  <button
                    type="button"
                    aria-label={isLightTheme ? '切换到深色模式' : '切换到浅色模式'}
                    onClick={() => setCanvasTheme((current) => (current === 'light' ? 'dark' : 'light'))}
                    className={cn(
                      DASHBOARD_PILL_BUTTON_SM,
                      isLightTheme
                        ? 'border border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-50'
                        : 'border border-slate-700 bg-slate-900/80 text-slate-200 hover:border-slate-500 hover:bg-slate-900',
                    )}
                  >
                    {isLightTheme ? <MoonStar className="h-4 w-4" /> : <SunMedium className="h-4 w-4" />}
                    {isLightTheme ? '深色模式' : '浅色模式'}
                  </button>
                  <button
                    type="button"
                    onClick={() => {
                      onCommit(draftItems);
                      onClose();
                    }}
                    disabled={!hasDraftChanges}
                    className={cn(
                      DASHBOARD_PILL_BUTTON_SM,
                      isLightTheme
                        ? 'bg-emerald-600 text-white hover:bg-emerald-500 disabled:bg-slate-200 disabled:text-slate-400'
                        : 'bg-emerald-500 text-slate-950 hover:bg-emerald-400 disabled:bg-slate-700 disabled:text-slate-400',
                      'disabled:cursor-not-allowed',
                    )}
                  >
                    保存调整
                  </button>
                  <button
                    type="button"
                    aria-label="退出全屏"
                    onClick={() => setIsFullscreen(false)}
                    className={cn(
                      DASHBOARD_PILL_BUTTON_SM,
                      isLightTheme
                        ? 'border border-slate-200 bg-white text-slate-700 hover:border-slate-300 hover:bg-slate-50'
                        : 'border border-slate-700 bg-slate-900/80 text-slate-200 hover:border-slate-500 hover:bg-slate-900',
                    )}
                  >
                    <Minimize2 className="h-4 w-4" />
                    退出全屏
                  </button>
                </>
              ) : null}
            </div>
          </div>
          {!isFullscreen ? (
            <div className={cn('mt-3 flex flex-wrap items-center justify-between gap-3 text-xs', isLightTheme ? 'text-slate-500' : 'text-slate-400')}>
              <p>{viewSummary}</p>
              <p role="status" aria-live="polite" className="max-w-3xl text-right">
                {statusMessage || '拖拽工时卡片到目标任务节点，完成后点击右上角“保存调整”生效。'}
              </p>
            </div>
          ) : null}
        </div>

        <div
          aria-label="工时归属画布视口"
          onMouseDown={(event) => {
            if (event.button !== 0) {
              return;
            }
            const target = event.target as HTMLElement;
            if (target.closest('[data-canvas-card="true"]') || target.closest('[data-ignore-pan="true"]')) {
              return;
            }
            panOriginRef.current = {
              startX: event.clientX,
              startY: event.clientY,
              baseOffsetX: view.offsetX,
              baseOffsetY: view.offsetY,
            };
            setIsPanning(true);
          }}
          className={cn(
            'relative min-h-0 flex-1 overflow-hidden [background-size:24px_24px]',
            isLightTheme
              ? 'bg-white bg-[radial-gradient(circle_at_1px_1px,rgba(148,163,184,0.24)_1px,transparent_0)]'
              : 'bg-[radial-gradient(circle_at_1px_1px,rgba(148,163,184,0.16)_1px,transparent_0)]',
            isPanning ? 'cursor-grabbing' : 'cursor-grab',
          )}
        >
          <div
            className={cn(
              'pointer-events-none absolute inset-0',
              isLightTheme
                ? 'bg-[radial-gradient(circle_at_top,rgba(16,185,129,0.08),transparent_34%),radial-gradient(circle_at_bottom_right,rgba(59,130,246,0.08),transparent_28%)]'
                : 'bg-[radial-gradient(circle_at_top,rgba(34,197,94,0.14),transparent_34%),radial-gradient(circle_at_bottom_right,rgba(59,130,246,0.14),transparent_28%)]',
            )}
          />
          <div
            className="absolute left-0 top-0 origin-top-left transition-transform duration-200 ease-out"
            style={{
              width: `${canvasWidth}px`,
              height: `${canvasHeight}px`,
              transform: `translate(${view.offsetX}px, ${view.offsetY}px) scale(${view.scale})`,
            }}
          >
            {layoutNodes.length === 0 ? (
              <div
                className={cn(
                  'absolute left-24 top-24 rounded-[1.75rem] border border-dashed px-6 py-8 text-sm',
                  isLightTheme
                    ? 'border-slate-300 bg-white text-slate-500 shadow-sm'
                    : 'border-slate-700 bg-slate-900/80 text-slate-400',
                )}
              >
                当前筛选下没有可展示的任务或工时卡片。
              </div>
            ) : (
              layoutNodes.map((node, index) => {
                const { group } = node;
                const isActiveDropTarget =
                  activeDropTaskId !== null &&
                  ((group.taskId === null && activeDropTaskId === 'orphan') || group.taskId === activeDropTaskId);

                return (
                  <section
                    key={group.id}
                    role="group"
                    aria-label={`工时画布节点 ${group.title}`}
                    onDragOver={(event) => {
                      event.preventDefault();
                      setActiveDropTaskId(group.taskId ?? 'orphan');
                    }}
                    onDrop={(event) => {
                      event.preventDefault();
                      handleDrop(group.taskId, group.title);
                    }}
                    className={cn(
                      'group absolute overflow-hidden rounded-[1.75rem] border backdrop-blur-xl transition duration-200',
                      isLightTheme
                        ? group.isOrphan
                          ? 'border-amber-200 bg-amber-50/90 shadow-[0_18px_40px_rgba(245,158,11,0.12)]'
                          : 'border-slate-200 bg-white shadow-[0_18px_40px_rgba(15,23,42,0.10)]'
                        : group.isOrphan
                          ? 'border-amber-400/30 bg-amber-500/10 shadow-[0_24px_60px_rgba(245,158,11,0.12)]'
                          : 'border-slate-800/90 bg-slate-900/88 shadow-[0_28px_70px_rgba(15,23,42,0.42)]',
                      isActiveDropTarget
                        ? isLightTheme
                          ? 'ring-2 ring-emerald-500/70 ring-offset-2 ring-offset-white'
                          : 'ring-2 ring-emerald-400/70 ring-offset-2 ring-offset-slate-950'
                        : '',
                    )}
                    style={{
                      left: `${node.x}px`,
                      top: `${node.y}px`,
                      width: `${node.scaledWidth}px`,
                      height: `${node.scaledHeight}px`,
                    }}
                    >
                    {index < layoutNodes.length - 1 ? (
                      <div
                        aria-hidden="true"
                        className="pointer-events-none absolute left-[calc(100%+10px)] top-12 h-px w-12 bg-gradient-to-r from-emerald-400/40 to-transparent"
                      />
                    ) : null}
                    <button
                      type="button"
                      aria-label={`拖拽任务模块边框 ${group.title}`}
                      data-ignore-pan="true"
                      onMouseDown={(event) => startNodeDrag(event, node)}
                      className="absolute inset-x-0 top-0 z-10 h-5 cursor-move rounded-t-[1.75rem] bg-transparent focus:outline-none"
                    >
                      <span
                        data-node-drag-glow="true"
                        aria-hidden="true"
                        className={cn(
                          'pointer-events-none absolute inset-x-6 top-0 h-px rounded-full opacity-0 transition-all duration-200 group-hover:opacity-100 group-focus-within:opacity-100',
                          isLightTheme
                            ? 'bg-gradient-to-r from-transparent via-emerald-500/70 to-transparent shadow-[0_0_10px_rgba(16,185,129,0.25)]'
                            : 'bg-gradient-to-r from-transparent via-emerald-400/80 to-transparent shadow-[0_0_12px_rgba(52,211,153,0.32)]',
                        )}
                      />
                    </button>
                    <div
                      data-node-content="true"
                      className="origin-top-left"
                      style={{
                        width: `${node.width}px`,
                        height: `${node.height}px`,
                        transform: `scale(${node.scale})`,
                      }}
                    >
                      <div className={cn('px-5 py-4', isLightTheme ? 'border-b border-slate-200' : 'border-b border-slate-800/80')}>
                        <div className="flex items-start justify-between gap-3">
                          <div>
                            <div className="flex flex-wrap items-center gap-2">
                              {group.isOrphan ? (
                                <AlertTriangle className={cn('h-4 w-4', isLightTheme ? 'text-amber-600' : 'text-amber-300')} />
                              ) : (
                                <ListTree className={cn('h-4 w-4', isLightTheme ? 'text-emerald-600' : 'text-emerald-300')} />
                              )}
                              <h4 className={cn('text-base font-semibold', isLightTheme ? 'text-slate-900' : 'text-white')}>{group.title}</h4>
                            </div>
                            <p className={cn('mt-2 text-sm', isLightTheme ? 'text-slate-600' : 'text-slate-300')}>
                              {group.entryCount} 条记录 · {formatNumber(group.totalMinutes)} 分钟
                            </p>
                          </div>
                          <div className="flex flex-wrap items-center justify-end gap-2">
                            <div
                              className={cn(
                                'rounded-full px-3 py-1 text-xs',
                                isLightTheme
                                  ? 'border border-slate-200 bg-slate-50 text-slate-600'
                                  : 'border border-slate-700 bg-slate-950/80 text-slate-300',
                              )}
                            >
                              {group.task?.estimated_minutes
                                ? `预估 ${formatNumber(Number(group.task.estimated_minutes))} 分钟`
                                : group.isOrphan
                                  ? '异常归属兜底'
                                  : '待分配'}
                            </div>
                            <div
                              className={cn(
                                'rounded-full px-3 py-1 text-xs font-medium',
                                isLightTheme
                                  ? 'border border-emerald-200 bg-emerald-50 text-emerald-700'
                                  : 'border border-emerald-500/20 bg-emerald-500/10 text-emerald-300',
                              )}
                            >
                              节点 {Math.round(node.scale * 100)}%
                            </div>
                          </div>
                        </div>
                      </div>

                      <div className="space-y-3 p-4">
                        {group.entries.length === 0 ? (
                          <div
                            className={cn(
                              'rounded-2xl border border-dashed px-4 py-8 text-sm',
                              isLightTheme
                                ? 'border-slate-300 bg-slate-50 text-slate-500'
                                : 'border-slate-700 bg-slate-950/70 text-slate-400',
                            )}
                          >
                            把工时卡片拖到这里，重新归属到“{group.title}”。
                          </div>
                        ) : (
                          group.entries.map((entry) => {
                            const entryId = toNumericId(entry.id);
                            const entryLabel = getEntryLabel(entry);
                            const isDragging = entryId !== null && draggingEntryId === entryId;

                            return (
                              <div
                                key={entryId ?? entryLabel}
                                data-canvas-card="true"
                                role="button"
                                tabIndex={0}
                                draggable={entryId !== null}
                                aria-label={`工时卡片 ${entryLabel}`}
                                onKeyDown={(event) => {
                                  if (event.key === 'Escape') {
                                    clearDragState();
                                  }
                                }}
                                onDragStart={(event) => {
                                  if (entryId === null) {
                                    return;
                                  }
                                  setDraggingEntryId(entryId);
                                  setStatusMessage(`正在拖拽“${entryLabel}”`);
                                  event.dataTransfer?.setData('text/plain', String(entryId));
                                }}
                                onDragEnd={clearDragState}
                                className={cn(
                                  'cursor-grab rounded-[1.35rem] border p-4 transition focus:outline-none focus:ring-2',
                                  isLightTheme
                                    ? 'border-slate-200 bg-white hover:border-emerald-300 hover:bg-emerald-50/40 focus:ring-emerald-500/70'
                                    : 'border-slate-800/80 bg-slate-950/88 hover:border-emerald-400/30 hover:bg-slate-900 focus:ring-emerald-400/70',
                                  isDragging
                                    ? 'border-emerald-400/70 shadow-[0_0_0_1px_rgba(52,211,153,0.35)]'
                                    : '',
                                )}
                              >
                                <div className="flex items-start justify-between gap-3">
                                  <div className="min-w-0 flex-1">
                                    <div className={cn('flex items-center gap-2', isLightTheme ? 'text-slate-500' : 'text-slate-400')}>
                                      <GripVertical className="h-4 w-4 shrink-0" />
                                      <span className={cn('truncate text-sm font-semibold', isLightTheme ? 'text-slate-900' : 'text-slate-100')}>{entryLabel}</span>
                                    </div>
                                    <p className={cn('mt-2 text-xs leading-5', isLightTheme ? 'text-slate-500' : 'text-slate-400')}>
                                      {formatTimestamp(Number(entry.work_date ?? entry.created_at ?? Date.now()))}
                                    </p>
                                  </div>
                                  <div
                                    className={cn(
                                      'shrink-0 rounded-full px-3 py-1 text-xs font-medium',
                                      isLightTheme ? 'bg-slate-100 text-slate-700' : 'bg-slate-900 text-slate-200',
                                    )}
                                  >
                                    <span className="inline-flex items-center gap-1">
                                      <Clock3 className="h-3.5 w-3.5" />
                                      {formatNumber(Number(entry.minutes ?? 0))} 分钟
                                    </span>
                                  </div>
                                </div>
                              </div>
                            );
                          })
                        )}
                      </div>
                    </div>
                    <button
                      type="button"
                      aria-label={`缩放任务树边框 ${group.title}`}
                      data-ignore-pan="true"
                      onMouseDown={(event) => startNodeResize(event, node)}
                      className="absolute bottom-0 right-0 z-10 h-12 w-12 cursor-nwse-resize rounded-br-[1.75rem] bg-transparent focus:outline-none"
                    >
                      <span
                        data-node-resize-glow="true"
                        aria-hidden="true"
                        className={cn(
                          'pointer-events-none absolute bottom-0 right-0 h-9 w-9 rounded-br-[1.75rem] border-b border-r opacity-0 transition-all duration-200 group-hover:opacity-100 group-focus-within:opacity-100',
                          isLightTheme
                            ? 'border-emerald-400/90 shadow-[0_0_12px_rgba(16,185,129,0.22)]'
                            : 'border-emerald-300/90 shadow-[0_0_14px_rgba(52,211,153,0.28)]',
                        )}
                      />
                    </button>
                  </section>
                );
              })
            )}
          </div>
        </div>
      </div>
    </div>
  );

  return createPortal(dialogContent, document.body);
}
