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
  taskTags?: WorkLogRow[];
  tagNames?: Record<string, string>;
  onClose: () => void;
  onCommit: (items: WorkLogRow[]) => void;
  onCommitToBackend?: (items: WorkLogRow[]) => void;
  savePending?: boolean;
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

interface HoverPreviewRect {
  top: number;
  left: number;
  right: number;
  bottom: number;
}

interface HoverPreviewState {
  entry: WorkLogRow;
  entryLabel: string;
  cardRect: HoverPreviewRect;
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
const HOVER_PREVIEW_DELAY_MS = 500;
const HOVER_PREVIEW_WIDTH = 360;
const HOVER_PREVIEW_HEIGHT = 240;
const HOVER_PREVIEW_GAP = 20;
const HOVER_PREVIEW_VIEWPORT_PADDING = 24;
const TASK_STATUS_OPTIONS = [
  { value: '0', label: '待办' },
  { value: '1', label: '进行中' },
  { value: '2', label: '已完成' },
  { value: '3', label: '已取消' },
] as const;

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
  taskTags = [],
  tagNames = {},
  onClose,
  onCommit,
  onCommitToBackend,
  savePending = false,
}: WorkLogTimeCanvasDialogProps) {
  const closeButtonRef = useRef<HTMLButtonElement | null>(null);
  const panOriginRef = useRef<PanOrigin | null>(null);
  const nodeDragOriginRef = useRef<NodeDragOrigin | null>(null);
  const nodeResizeOriginRef = useRef<NodeResizeOrigin | null>(null);
  const hoverPreviewTimerRef = useRef<number | null>(null);
  const [query, setQuery] = useState('');
  const [selectedStatus, setSelectedStatus] = useState('all');
  const [selectedTagId, setSelectedTagId] = useState('all');
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
  const [hoverPreview, setHoverPreview] = useState<HoverPreviewState | null>(null);

  const clearHoverPreviewTimer = () => {
    if (hoverPreviewTimerRef.current === null) {
      return;
    }
    window.clearTimeout(hoverPreviewTimerRef.current);
    hoverPreviewTimerRef.current = null;
  };

  const hideHoverPreview = () => {
    clearHoverPreviewTimer();
    setHoverPreview(null);
  };

  const scheduleHoverPreview = (entry: WorkLogRow, cardElement: HTMLDivElement) => {
    if (draggingEntryId !== null || nodeDragOriginRef.current || nodeResizeOriginRef.current || isPanning) {
      return;
    }

    hideHoverPreview();
    hoverPreviewTimerRef.current = window.setTimeout(() => {
      const rect = cardElement.getBoundingClientRect();
      setHoverPreview({
        entry,
        entryLabel: getEntryLabel(entry),
        cardRect: {
          top: rect.top,
          left: rect.left,
          right: rect.right,
          bottom: rect.bottom,
        },
      });
      hoverPreviewTimerRef.current = null;
    }, HOVER_PREVIEW_DELAY_MS);
  };

  useEffect(() => {
    if (typeof window === 'undefined') {
      return;
    }

    window.localStorage.setItem(CANVAS_THEME_STORAGE_KEY, canvasTheme);
  }, [canvasTheme]);

  useEffect(() => {
    if (!open) {
      hideHoverPreview();
      return;
    }
    setDraftItems(items);
    setQuery('');
    setSelectedStatus('all');
    setSelectedTagId('all');
    setDraggingEntryId(null);
    setActiveDropTaskId(null);
    setStatusMessage('');
    setLastReassignment(null);
    setView(DEFAULT_VIEW);
    setNodePositions({});
    setNodeScales({});
    setIsPanning(false);
    setHoverPreview(null);
    panOriginRef.current = null;
    nodeDragOriginRef.current = null;
    nodeResizeOriginRef.current = null;
  }, [items, open]);

  useEffect(() => () => {
    clearHoverPreviewTimer();
  }, []);

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

  const taskTagIdsByTaskId = useMemo(() => {
    const mapping = new Map<number, number[]>();
    taskTags.forEach((row) => {
      const taskId = toNumericId(row.task_id);
      const tagId = toNumericId(row.tag_id);
      if (taskId === null || tagId === null) {
        return;
      }
      const current = mapping.get(taskId) ?? [];
      if (!current.includes(tagId)) {
        mapping.set(taskId, [...current, tagId]);
      }
    });
    return mapping;
  }, [taskTags]);

  const taskTagOptions = useMemo(
    () =>
      Array.from(taskTagIdsByTaskId.values())
        .flat()
        .filter((tagId, index, values) => values.indexOf(tagId) === index)
        .map((tagId) => ({
          value: String(tagId),
          label: tagNames[String(tagId)] ?? `标签#${tagId}`,
        }))
        .sort((left, right) => left.label.localeCompare(right.label, 'zh-CN')),
    [tagNames, taskTagIdsByTaskId],
  );

  const resolveTaskTitle = (taskId: number | null) => {
    if (taskId === null) {
      return ORPHAN_TASK_TITLE;
    }
    return taskTitleMap.get(taskId) ?? `任务#${taskId}`;
  };

  const groups = useMemo(() => {
    const keyword = query.trim().toLowerCase();
    const tree = buildWorkLogTree(tasks, draftItems).filter((group) => {
      if (group.isOrphan) {
        return selectedStatus === 'all' && selectedTagId === 'all';
      }

      const statusMatches = selectedStatus === 'all' || String(group.task?.status ?? '') === selectedStatus;
      const tagMatches = selectedTagId === 'all'
        || (group.taskId !== null && (taskTagIdsByTaskId.get(group.taskId) ?? []).includes(Number(selectedTagId)));

      return statusMatches && tagMatches;
    });

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
  }, [draftItems, query, selectedStatus, selectedTagId, taskTagIdsByTaskId, tasks]);

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
  const hoverPreviewPosition = useMemo(() => {
    if (!hoverPreview || typeof window === 'undefined') {
      return null;
    }

    const maxLeft = window.innerWidth - HOVER_PREVIEW_WIDTH - HOVER_PREVIEW_VIEWPORT_PADDING;
    const preferredRight = hoverPreview.cardRect.right + HOVER_PREVIEW_GAP;
    const preferredLeft = hoverPreview.cardRect.left - HOVER_PREVIEW_WIDTH - HOVER_PREVIEW_GAP;
    const left = preferredRight <= maxLeft
      ? preferredRight
      : Math.max(HOVER_PREVIEW_VIEWPORT_PADDING, Math.min(preferredLeft, maxLeft));
    const top = Math.max(
      HOVER_PREVIEW_VIEWPORT_PADDING,
      Math.min(
        hoverPreview.cardRect.top - 12,
        window.innerHeight - HOVER_PREVIEW_HEIGHT - HOVER_PREVIEW_VIEWPORT_PADDING,
      ),
    );

    return {
      left: `${left}px`,
      top: `${top}px`,
    };
  }, [hoverPreview]);

  const commitDraftChanges = () => {
    onCommit(draftItems);
    onClose();
  };

  const commitChangesToBackend = () => {
    if (!onCommitToBackend) {
      return;
    }
    onCommitToBackend(draftItems);
    onClose();
  };

  const clearDragState = () => {
    hideHoverPreview();
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

    if (targetTaskId === null) {
      setStatusMessage(`“${entryLabel}”必须归属到任务后才能保存，不能拖到“${ORPHAN_TASK_TITLE}”`);
      clearDragState();
      return false;
    }

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
    hideHoverPreview();
    setView((current) => ({
      ...current,
      scale: clampScale(current.scale + SCALE_STEP),
    }));
  };

  const zoomOut = () => {
    hideHoverPreview();
    setView((current) => ({
      ...current,
      scale: clampScale(current.scale - SCALE_STEP),
    }));
  };

  const resetView = () => {
    hideHoverPreview();
    setView(DEFAULT_VIEW);
    setIsPanning(false);
    panOriginRef.current = null;
  };

  const startNodeDrag = (event: ReactMouseEvent<HTMLElement>, node: CanvasLayoutNode) => {
    event.preventDefault();
    event.stopPropagation();
    hideHoverPreview();
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
    hideHoverPreview();
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
                    像白板一样在画布中浏览任务与工时卡片，拖拽即可改归属；调整完成后直接保存即可。
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
                  onClick={onCommitToBackend ? commitChangesToBackend : commitDraftChanges}
                  disabled={!hasDraftChanges || (Boolean(onCommitToBackend) && savePending)}
                  className={cn(
                    DASHBOARD_PILL_BUTTON_MD,
                    isLightTheme
                      ? 'bg-emerald-600 text-white hover:bg-emerald-500 disabled:bg-slate-200 disabled:text-slate-400'
                      : 'bg-emerald-500 text-slate-950 hover:bg-emerald-400 disabled:bg-slate-700 disabled:text-slate-400',
                    'disabled:cursor-not-allowed',
                  )}
                >
                  {savePending && onCommitToBackend ? '保存中...' : '保存'}
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
              <label
                className={cn(
                  'flex items-center gap-2 rounded-full px-3 py-2 text-sm',
                  isLightTheme
                    ? 'border border-slate-200 bg-slate-50 text-slate-700'
                    : 'border border-slate-800 bg-slate-900/80 text-slate-300',
                )}
              >
                <span className="text-xs font-medium">状态</span>
                <select
                  aria-label="按任务状态筛选"
                  value={selectedStatus}
                  onChange={(event) => {
                    hideHoverPreview();
                    setSelectedStatus(event.target.value);
                  }}
                  className={cn(
                    'min-w-[112px] bg-transparent text-sm outline-none',
                    isLightTheme ? 'text-slate-900' : 'text-slate-100',
                  )}
                >
                  <option value="all">全部状态</option>
                  {TASK_STATUS_OPTIONS.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
              </label>
              <label
                className={cn(
                  'flex items-center gap-2 rounded-full px-3 py-2 text-sm',
                  isLightTheme
                    ? 'border border-slate-200 bg-slate-50 text-slate-700'
                    : 'border border-slate-800 bg-slate-900/80 text-slate-300',
                )}
              >
                <span className="text-xs font-medium">标签</span>
                <select
                  aria-label="按任务标签筛选"
                  value={selectedTagId}
                  onChange={(event) => {
                    hideHoverPreview();
                    setSelectedTagId(event.target.value);
                  }}
                  className={cn(
                    'min-w-[112px] bg-transparent text-sm outline-none',
                    isLightTheme ? 'text-slate-900' : 'text-slate-100',
                  )}
                >
                  <option value="all">全部标签</option>
                  {taskTagOptions.map((option) => (
                    <option key={option.value} value={option.value}>
                      {option.label}
                    </option>
                  ))}
                </select>
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
                    onClick={onCommitToBackend ? commitChangesToBackend : commitDraftChanges}
                    disabled={!hasDraftChanges || (Boolean(onCommitToBackend) && savePending)}
                    className={cn(
                      DASHBOARD_PILL_BUTTON_SM,
                      isLightTheme
                        ? 'bg-emerald-600 text-white hover:bg-emerald-500 disabled:bg-slate-200 disabled:text-slate-400'
                        : 'bg-emerald-500 text-slate-950 hover:bg-emerald-400 disabled:bg-slate-700 disabled:text-slate-400',
                      'disabled:cursor-not-allowed',
                    )}
                  >
                    {savePending && onCommitToBackend ? '保存中...' : '保存'}
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
                {statusMessage || '拖拽工时卡片到目标任务节点，完成后点击右上角“保存”生效。'}
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
            hideHoverPreview();
            panOriginRef.current = {
              startX: event.clientX,
              startY: event.clientY,
              baseOffsetX: view.offsetX,
              baseOffsetY: view.offsetY,
            };
            setIsPanning(true);
          }}
          className={cn(
            'relative min-h-0 flex-1 overflow-hidden [background-size:20px_20px]',
            isLightTheme
              ? 'bg-slate-50/40 bg-[radial-gradient(circle_at_1px_1px,rgba(148,163,184,0.18)_1px,transparent_0)]'
              : 'bg-slate-950 bg-[radial-gradient(circle_at_1px_1px,rgba(148,163,184,0.10)_1px,transparent_0)]',
            isPanning ? 'cursor-grabbing' : 'cursor-grab',
          )}
        >
          <div
            className={cn(
              'pointer-events-none absolute inset-0',
              isLightTheme
                ? 'bg-[radial-gradient(ellipse_at_top_left,rgba(16,185,129,0.06),transparent_44%),radial-gradient(ellipse_at_bottom_right,rgba(59,130,246,0.06),transparent_44%),radial-gradient(ellipse_at_center,rgba(168,85,247,0.03),transparent_50%)]'
                : 'bg-[radial-gradient(ellipse_at_top_left,rgba(34,197,94,0.10),transparent_44%),radial-gradient(ellipse_at_bottom_right,rgba(59,130,246,0.10),transparent_44%),radial-gradient(ellipse_at_center,rgba(168,85,247,0.05),transparent_50%)]',
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
                const canAcceptDrop = !group.isOrphan;
                const isActiveDropTarget =
                  activeDropTaskId !== null &&
                  ((group.taskId === null && activeDropTaskId === 'orphan') || group.taskId === activeDropTaskId);

                return (
                  <section
                    key={group.id}
                    role="group"
                    aria-label={`工时画布节点 ${group.title}`}
                    data-ignore-pan="true"
                    onMouseDown={(event) => {
                      if (event.button !== 0) return;
                      const target = event.target as HTMLElement;
                      if (target.closest('[data-canvas-card="true"]')) return;
                      startNodeDrag(event, node);
                    }}
                    onDragOver={(event) => {
                      if (!canAcceptDrop) {
                        return;
                      }
                      event.preventDefault();
                      setActiveDropTaskId(group.taskId ?? 'orphan');
                    }}
                    onDrop={(event) => {
                      if (!canAcceptDrop) {
                        return;
                      }
                      event.preventDefault();
                      handleDrop(group.taskId, group.title);
                    }}
                    className={cn(
                      'group absolute cursor-move overflow-hidden rounded-[1.75rem] border backdrop-blur-xl transition duration-200',
                      isLightTheme
                        ? group.isOrphan
                          ? 'border-amber-200/80 bg-gradient-to-b from-amber-50/95 to-white/90 shadow-[0_4px_12px_rgba(245,158,11,0.06),0_20px_44px_rgba(245,158,11,0.10)]'
                          : 'border-slate-200/70 bg-gradient-to-b from-white to-slate-50/40 shadow-[0_4px_12px_rgba(15,23,42,0.03),0_20px_44px_rgba(15,23,42,0.08)]'
                        : group.isOrphan
                          ? 'border-amber-400/20 bg-gradient-to-b from-amber-500/10 to-slate-950/80 shadow-[0_4px_16px_rgba(245,158,11,0.06),0_28px_56px_rgba(245,158,11,0.12)]'
                          : 'border-slate-700/50 bg-gradient-to-b from-slate-900/95 to-slate-950/90 shadow-[0_4px_16px_rgba(0,0,0,0.08),0_28px_56px_rgba(15,23,42,0.40)]',
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
                    <div
                      aria-hidden="true"
                      className={cn(
                        'pointer-events-none absolute inset-x-0 top-0 h-[3px]',
                        isLightTheme
                          ? group.isOrphan
                            ? 'bg-gradient-to-r from-amber-200 via-amber-400 to-amber-200'
                            : 'bg-gradient-to-r from-emerald-200 via-emerald-400 to-emerald-200'
                          : group.isOrphan
                            ? 'bg-gradient-to-r from-amber-500/60 via-amber-300 to-amber-500/60'
                            : 'bg-gradient-to-r from-emerald-500/60 via-emerald-300 to-emerald-500/60',
                      )}
                    />
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
                      className={cn(
                        'absolute inset-x-0 top-0 z-10 flex h-6 cursor-move items-center justify-center rounded-t-[1.75rem] transition-colors duration-200 focus:outline-none',
                        isLightTheme ? 'hover:bg-slate-100/50' : 'hover:bg-slate-800/30',
                      )}
                    >
                      <span
                        data-node-drag-glow="true"
                        aria-hidden="true"
                        className={cn(
                          'pointer-events-none h-[3px] w-8 rounded-full transition-all duration-200',
                          isLightTheme
                            ? group.isOrphan
                              ? 'bg-amber-300/25 group-hover:bg-amber-400/50'
                              : 'bg-slate-300/25 group-hover:bg-emerald-400/45'
                            : group.isOrphan
                              ? 'bg-amber-400/15 group-hover:bg-amber-300/40'
                              : 'bg-slate-600/20 group-hover:bg-emerald-400/40',
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
                      {group.task?.estimated_minutes ? (() => {
                        const estimated = Number(group.task.estimated_minutes);
                        const ratio = estimated > 0 ? group.totalMinutes / estimated : 0;
                        const pct = Math.min(100, Math.round(ratio * 100));
                        return (
                          <div className={cn('px-5 pb-1', isLightTheme ? 'bg-white/60' : 'bg-slate-900/40')}>
                            <div
                              className={cn(
                                'h-1 overflow-hidden rounded-full',
                                isLightTheme ? 'bg-slate-100' : 'bg-slate-800/80',
                              )}
                            >
                              <div
                                className={cn(
                                  'h-full rounded-full transition-all duration-500',
                                  ratio > 1
                                    ? 'bg-gradient-to-r from-red-400 to-red-500'
                                    : ratio > 0.8
                                      ? 'bg-gradient-to-r from-amber-400 to-amber-500'
                                      : 'bg-gradient-to-r from-emerald-400 to-emerald-500',
                                )}
                                style={{ width: `${pct}%` }}
                              />
                            </div>
                            <p className={cn('mt-1 text-[10px]', isLightTheme ? 'text-slate-400' : 'text-slate-500')}>
                              已用 {pct}%
                            </p>
                          </div>
                        );
                      })() : null}

                      <div className="space-y-3 p-4">
                        {group.entries.length === 0 ? (
                          <div
                            className={cn(
                              'flex flex-col items-center gap-2 rounded-2xl border border-dashed px-4 py-8 text-center text-sm',
                              isLightTheme
                                ? 'border-slate-300/70 bg-slate-50/50 text-slate-400'
                                : 'border-slate-700/50 bg-slate-900/30 text-slate-500',
                            )}
                          >
                            <Move className={cn('h-5 w-5', isLightTheme ? 'text-slate-300' : 'text-slate-600')} />
                            {group.isOrphan
                              ? '这里仅展示异常归属记录，不能作为新的归属目标。'
                              : `把工时卡片拖到这里，重新归属到“${group.title}”。`}
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
                                onMouseEnter={(event) => {
                                  scheduleHoverPreview(entry, event.currentTarget);
                                }}
                                onMouseLeave={hideHoverPreview}
                                onFocus={(event) => {
                                  scheduleHoverPreview(entry, event.currentTarget);
                                }}
                                onBlur={hideHoverPreview}
                                onKeyDown={(event) => {
                                  if (event.key === 'Escape') {
                                    clearDragState();
                                  }
                                }}
                                onDragStart={(event) => {
                                  if (entryId === null) {
                                    return;
                                  }
                                  hideHoverPreview();
                                  setDraggingEntryId(entryId);
                                  setStatusMessage(`正在拖拽“${entryLabel}”`);
                                  event.dataTransfer?.setData('text/plain', String(entryId));
                                }}
                                onDragEnd={clearDragState}
                                className={cn(
                                  'cursor-grab rounded-[1.35rem] border border-l-[3px] p-4 transition-all duration-200 focus:outline-none focus:ring-2',
                                  isLightTheme
                                    ? 'border-slate-200/80 border-l-emerald-300 bg-white hover:border-emerald-200 hover:border-l-emerald-400 hover:shadow-[0_4px_16px_rgba(16,185,129,0.10)] focus:ring-emerald-500/70'
                                    : 'border-slate-700/50 border-l-emerald-500/40 bg-slate-900/60 hover:border-emerald-500/30 hover:border-l-emerald-400/60 hover:shadow-[0_4px_16px_rgba(52,211,153,0.08)] focus:ring-emerald-400/70',
                                  isDragging
                                    ? isLightTheme
                                      ? 'scale-[1.02] border-emerald-300 border-l-emerald-500 bg-emerald-50/50 shadow-[0_8px_24px_rgba(16,185,129,0.16)]'
                                      : 'scale-[1.02] border-emerald-400/40 border-l-emerald-400 bg-emerald-500/8 shadow-[0_8px_24px_rgba(52,211,153,0.14)]'
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
                                      isLightTheme ? 'bg-blue-50 text-blue-700' : 'bg-blue-500/10 text-blue-300',
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
                      className={cn(
                        'absolute bottom-0 right-0 z-10 flex h-10 w-10 cursor-nwse-resize items-end justify-end rounded-br-[1.75rem] p-2 transition-colors duration-200 focus:outline-none',
                        isLightTheme ? 'hover:bg-slate-100/50' : 'hover:bg-slate-800/30',
                      )}
                    >
                      <svg
                        data-node-resize-glow="true"
                        aria-hidden="true"
                        width="10"
                        height="10"
                        viewBox="0 0 10 10"
                        className={cn(
                          'pointer-events-none transition-all duration-200',
                          isLightTheme
                            ? group.isOrphan
                              ? 'text-amber-300/30 group-hover:text-amber-400/60'
                              : 'text-slate-300/30 group-hover:text-emerald-400/55'
                            : group.isOrphan
                              ? 'text-amber-400/20 group-hover:text-amber-300/50'
                              : 'text-slate-600/20 group-hover:text-emerald-400/45',
                        )}
                      >
                        <circle cx="8" cy="2" r="1" fill="currentColor" />
                        <circle cx="5" cy="5" r="1" fill="currentColor" />
                        <circle cx="8" cy="5" r="1" fill="currentColor" />
                        <circle cx="2" cy="8" r="1" fill="currentColor" />
                        <circle cx="5" cy="8" r="1" fill="currentColor" />
                        <circle cx="8" cy="8" r="1" fill="currentColor" />
                      </svg>
                    </button>
                  </section>
                );
              })
            )}
          </div>
        </div>
      </div>
      {hoverPreview && hoverPreviewPosition ? (
        <aside
          role="tooltip"
          aria-label={`工时详情浮窗 ${hoverPreview.entryLabel}`}
          className={cn(
            'pointer-events-none fixed z-[140] w-[360px] max-w-[calc(100vw-48px)] overflow-hidden rounded-[1.75rem] border shadow-[0_24px_80px_rgba(15,23,42,0.28)] backdrop-blur-xl',
            isLightTheme
              ? 'border-slate-200/90 bg-white/96 text-slate-900'
              : 'border-slate-700/80 bg-slate-950/95 text-slate-100',
          )}
          style={hoverPreviewPosition}
        >
          <div className="space-y-4 px-5 py-5">
            <div>
              <p className={cn('text-[11px] font-semibold uppercase tracking-[0.2em]', isLightTheme ? 'text-slate-500' : 'text-slate-400')}>
                内容全文
              </p>
              <p className={cn('mt-2 text-sm leading-6 whitespace-pre-wrap', isLightTheme ? 'text-slate-700' : 'text-slate-100')}>
                {String(hoverPreview.entry.content ?? hoverPreview.entryLabel)}
              </p>
            </div>
            <div className="grid grid-cols-2 gap-3 text-sm">
              <div
                className={cn(
                  'rounded-2xl px-4 py-3',
                  isLightTheme ? 'bg-slate-50 text-slate-600' : 'bg-slate-900/80 text-slate-300',
                )}
              >
                <p className={cn('text-[11px] font-semibold uppercase tracking-[0.18em]', isLightTheme ? 'text-slate-400' : 'text-slate-500')}>
                  记录 ID
                </p>
                <p className={cn('mt-2 font-medium', isLightTheme ? 'text-slate-900' : 'text-slate-100')}>
                  {String(hoverPreview.entry.id ?? 'unknown')}
                </p>
              </div>
              <div
                className={cn(
                  'rounded-2xl px-4 py-3',
                  isLightTheme ? 'bg-slate-50 text-slate-600' : 'bg-slate-900/80 text-slate-300',
                )}
              >
                <p className={cn('text-[11px] font-semibold uppercase tracking-[0.18em]', isLightTheme ? 'text-slate-400' : 'text-slate-500')}>
                  最近更新时间
                </p>
                <p className={cn('mt-2 font-medium leading-5', isLightTheme ? 'text-slate-900' : 'text-slate-100')}>
                  {formatTimestamp(Number(hoverPreview.entry.updated_at ?? hoverPreview.entry.work_date ?? hoverPreview.entry.created_at ?? Date.now()))}
                </p>
              </div>
            </div>
          </div>
        </aside>
      ) : null}
    </div>
  );

  return createPortal(dialogContent, document.body);
}
