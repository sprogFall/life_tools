import type { DashboardUserDetailResponse } from '@/lib/types';
import { getToolDisplayText } from '@/lib/tool-display';

export interface RelationOption {
  value: string | number;
  label: string;
}

export interface DashboardRelationContext {
  taskNames: Record<string, string>;
  timeEntryNames: Record<string, string>;
  stockItemNames: Record<string, string>;
  recipeNames: Record<string, string>;
  mealNames: Record<string, string>;
  tagNames: Record<string, string>;
  toolOptions: RelationOption[];
  categoryOptionsByToolId: Record<string, RelationOption[]>;
  tagOptionsByToolId: Record<string, RelationOption[]>;
  tagOptionsByToolCategory: Record<string, RelationOption[]>;
}

export interface FriendlyValueArgs {
  toolId: string;
  sectionKey: string;
  fieldKey: string;
  value: unknown;
  row?: Record<string, unknown>;
  context: DashboardRelationContext;
}

export interface FieldEditorMetaArgs extends FriendlyValueArgs {}

export interface FieldEditorMeta {
  kind: 'input' | 'select';
  valueType: 'string' | 'number';
  options: RelationOption[];
}

const TOOL_CATEGORY_NAMES: Record<string, Record<string, string>> = {
  work_log: {
    affiliation: '归属',
  },
  stockpile_assistant: {
    item_type: '物品类型',
    location: '位置',
  },
  overcooked_kitchen: {
    dish_type: '菜品风格',
    ingredient: '主料',
    sauce: '调味',
    flavor: '风味',
    meal_slot: '餐次',
  },
};

const WORK_TASK_STATUS_OPTIONS: RelationOption[] = [
  { value: 0, label: '待办' },
  { value: 1, label: '进行中' },
  { value: 2, label: '已完成' },
  { value: 3, label: '已取消' },
];

const OPERATION_TYPE_OPTIONS: RelationOption[] = [
  { value: 0, label: '创建任务' },
  { value: 1, label: '更新任务' },
  { value: 2, label: '删除任务' },
  { value: 3, label: '创建工时' },
  { value: 4, label: '更新工时' },
  { value: 5, label: '删除工时' },
];

const TARGET_TYPE_OPTIONS: RelationOption[] = [
  { value: 0, label: '任务' },
  { value: 1, label: '工时记录' },
];

const SYNC_NETWORK_TYPE_OPTIONS: RelationOption[] = [
  { value: 0, label: '公网模式' },
  { value: 1, label: '私有 Wi-Fi' },
];

const THEME_MODE_OPTIONS: RelationOption[] = [
  { value: 'light', label: '浅色' },
  { value: 'dark', label: '深色' },
  { value: 'system', label: '跟随系统' },
];

const OBJ_STORE_TYPE_OPTIONS: RelationOption[] = [
  { value: 'none', label: '未配置' },
  { value: 'local', label: '本地存储' },
  { value: 'qiniu', label: '七牛云' },
  { value: 'dataCapsule', label: '数据胶囊' },
];

const SYNC_DECISION_LABELS: Record<string, string> = {
  use_client: '以客户端为准',
  use_server: '以下发服务端为准',
  noop: '无变化',
  rollback: '回滚服务端快照',
  dashboard_update: '管理台更新',
};

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function asRows(
  detail: DashboardUserDetailResponse,
  toolId: string,
  sectionKey: string,
): Record<string, unknown>[] {
  const tool = detail.snapshot.tools_data[toolId];
  const toolData = asRecord(tool?.data);
  const raw = toolData?.[sectionKey];
  if (!Array.isArray(raw)) {
    return [];
  }
  return raw.map((item) => asRecord(item)).filter((x): x is Record<string, unknown> => x !== null);
}

function toIdLabelMap(
  rows: Record<string, unknown>[],
  getLabel: (row: Record<string, unknown>, id: string) => string,
) {
  return rows.reduce<Record<string, string>>((result, row) => {
    const rawId = row.id;
    if (typeof rawId !== 'number' && typeof rawId !== 'string') {
      return result;
    }
    const id = String(rawId);
    result[id] = getLabel(row, id);
    return result;
  }, {});
}

function compareLabels(left: RelationOption, right: RelationOption) {
  return left.label.localeCompare(right.label, 'zh-CN');
}

function formatDayKey(value: unknown) {
  const text = String(value ?? '').replace(/\D/g, '');
  if (text.length !== 8) {
    return String(value ?? '—');
  }
  return `${text.slice(0, 4)}-${text.slice(4, 6)}-${text.slice(6, 8)}`;
}

function formatEpoch(value: unknown, mode: 'date' | 'datetime') {
  const numeric = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(numeric) || numeric <= 0) {
    return String(value ?? '—');
  }
  return new Intl.DateTimeFormat('zh-CN',
    mode === 'date'
      ? { year: 'numeric', month: '2-digit', day: '2-digit' }
      : { year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit' },
  ).format(new Date(numeric));
}

function buildMealLabel(
  row: Record<string, unknown>,
  tagNames: Record<string, string>,
) {
  const dayText = formatDayKey(row.day_key);
  const mealTagId = row.meal_tag_id;
  if (typeof mealTagId === 'number' || typeof mealTagId === 'string') {
    const tagName = tagNames[String(mealTagId)];
    if (tagName) {
      return `${dayText} · ${tagName}`;
    }
  }
  return dayText;
}

function makeOptionsFromMap(map: Record<string, string>, valueType: 'string' | 'number') {
  return Object.entries(map)
    .map(([key, label]) => ({ value: valueType === 'number' ? Number(key) : key, label }))
    .sort(compareLabels);
}

function getToolCategoryName(toolId: string, categoryId: unknown) {
  if (typeof categoryId !== 'string') {
    return String(categoryId ?? '—');
  }
  return TOOL_CATEGORY_NAMES[toolId]?.[categoryId] ?? categoryId;
}

function getSectionCategoryId(sectionKey: string): string | null {
  switch (sectionKey) {
    case 'task_tags':
      return 'affiliation';
    case 'recipe_ingredient_tags':
      return 'ingredient';
    case 'recipe_sauce_tags':
      return 'sauce';
    case 'recipe_flavor_tags':
      return 'flavor';
    default:
      return null;
  }
}

function getTagOptionsForContext(
  context: DashboardRelationContext,
  toolId: string,
  categoryId?: string | null,
) {
  if (categoryId) {
    return context.tagOptionsByToolCategory[`${toolId}:${categoryId}`] ?? [];
  }
  return context.tagOptionsByToolId[toolId] ?? [];
}

function findLabel(options: RelationOption[], value: unknown) {
  return options.find((item) => String(item.value) === String(value))?.label;
}

function formatLookup(map: Record<string, string>, value: unknown) {
  const label = map[String(value)];
  return label ?? String(value ?? '—');
}

export function buildRelationContext(
  detail: DashboardUserDetailResponse,
): DashboardRelationContext {
  const tagRows = asRows(detail, 'tag_manager', 'tags');
  const toolTagRows = asRows(detail, 'tag_manager', 'tool_tags');
  const taskRows = asRows(detail, 'work_log', 'tasks');
  const timeEntryRows = asRows(detail, 'work_log', 'time_entries');
  const stockItemRows = asRows(detail, 'stockpile_assistant', 'items');
  const recipeRows = asRows(detail, 'overcooked_kitchen', 'recipes');
  const mealRows = asRows(detail, 'overcooked_kitchen', 'meals');

  const tagNames = toIdLabelMap(tagRows, (row, id) => String(row.name ?? `标签#${id}`));
  const taskNames = toIdLabelMap(taskRows, (row, id) => String(row.title ?? `任务#${id}`));
  const timeEntryNames = toIdLabelMap(
    timeEntryRows,
    (row, id) => String(row.content ?? `工时记录#${id}`),
  );
  const stockItemNames = toIdLabelMap(
    stockItemRows,
    (row, id) => String(row.name ?? `库存项#${id}`),
  );
  const recipeNames = toIdLabelMap(
    recipeRows,
    (row, id) => String(row.name ?? `菜谱#${id}`),
  );
  const mealNames = toIdLabelMap(mealRows, (row) => buildMealLabel(row, tagNames));

  const toolIds = Array.from(
    new Set([
      'work_log',
      'stockpile_assistant',
      'overcooked_kitchen',
      'tag_manager',
      ...detail.snapshot.tool_ids,
      ...toolTagRows.map((row) => String(row.tool_id ?? '')),
    ].filter(Boolean)),
  );

  const toolOptions = toolIds
    .map((toolId) => ({ value: toolId, label: getToolDisplayText(toolId) }))
    .sort(compareLabels);

  const categoryOptionsByToolId = Object.fromEntries(
    toolIds.map((toolId) => [
      toolId,
      Object.entries(TOOL_CATEGORY_NAMES[toolId] ?? {})
        .map(([value, label]) => ({ value, label }))
        .sort(compareLabels),
    ]),
  );

  const tagOptionsByToolCategory: Record<string, RelationOption[]> = {};
  const tagOptionsByToolId: Record<string, RelationOption[]> = {};
  const seenCategoryTags = new Set<string>();
  const seenToolTags = new Set<string>();

  for (const row of toolTagRows) {
    const toolId = String(row.tool_id ?? '');
    const categoryId = String(row.category_id ?? '');
    const tagId = row.tag_id;
    if (!toolId || !categoryId || (typeof tagId !== 'number' && typeof tagId !== 'string')) {
      continue;
    }
    const tagName = tagNames[String(tagId)] ?? `标签#${tagId}`;
    const categoryName = getToolCategoryName(toolId, categoryId);
    const baseOption = { value: Number(tagId), label: tagName };
    const key = `${toolId}:${categoryId}`;
    const categoryTagKey = `${key}:${tagId}`;
    if (!seenCategoryTags.has(categoryTagKey)) {
      seenCategoryTags.add(categoryTagKey);
      tagOptionsByToolCategory[key] = [...(tagOptionsByToolCategory[key] ?? []), baseOption].sort(compareLabels);
    }
    const toolTagKey = `${toolId}:${tagId}`;
    if (!seenToolTags.has(toolTagKey)) {
      seenToolTags.add(toolTagKey);
      tagOptionsByToolId[toolId] = [
        ...(tagOptionsByToolId[toolId] ?? []),
        { value: Number(tagId), label: `${categoryName} · ${tagName}` },
      ].sort(compareLabels);
    }
  }

  return {
    taskNames,
    timeEntryNames,
    stockItemNames,
    recipeNames,
    mealNames,
    tagNames,
    toolOptions,
    categoryOptionsByToolId,
    tagOptionsByToolId,
    tagOptionsByToolCategory,
  };
}

export function formatFriendlyValue({
  toolId,
  sectionKey,
  fieldKey,
  value,
  row,
  context,
}: FriendlyValueArgs) {
  if (value === null || value === undefined || value === '') {
    return '—';
  }
  if (typeof value === 'boolean') {
    return value ? '是' : '否';
  }
  if (Array.isArray(value)) {
    return value.length === 0 ? '—' : JSON.stringify(value);
  }

  const scopedKey = `${toolId}.${sectionKey}.${fieldKey}`;
  switch (scopedKey) {
    case 'work_log.tasks.status':
      return findLabel(WORK_TASK_STATUS_OPTIONS, value) ?? String(value);
    case 'work_log.time_entries.task_id':
    case 'work_log.task_tags.task_id':
      return formatLookup(context.taskNames, value);
    case 'work_log.task_tags.tag_id':
      return formatLookup(context.tagNames, value);
    case 'work_log.operation_logs.operation_type':
      return findLabel(OPERATION_TYPE_OPTIONS, value) ?? String(value);
    case 'work_log.operation_logs.target_type':
      return findLabel(TARGET_TYPE_OPTIONS, value) ?? String(value);
    case 'stockpile_assistant.consumptions.item_id':
    case 'stockpile_assistant.item_tags.item_id':
      return formatLookup(context.stockItemNames, value);
    case 'stockpile_assistant.item_tags.tag_id':
      return formatLookup(context.tagNames, value);
    case 'overcooked_kitchen.recipes.type_tag_id':
    case 'overcooked_kitchen.recipe_ingredient_tags.tag_id':
    case 'overcooked_kitchen.recipe_sauce_tags.tag_id':
    case 'overcooked_kitchen.recipe_flavor_tags.tag_id':
      return formatLookup(context.tagNames, value);
    case 'overcooked_kitchen.recipe_ingredient_tags.recipe_id':
    case 'overcooked_kitchen.recipe_sauce_tags.recipe_id':
    case 'overcooked_kitchen.recipe_flavor_tags.recipe_id':
    case 'overcooked_kitchen.wish_items.recipe_id':
    case 'overcooked_kitchen.meal_items.recipe_id':
    case 'overcooked_kitchen.meal_item_ratings.recipe_id':
      return formatLookup(context.recipeNames, value);
    case 'overcooked_kitchen.meals.meal_tag_id':
      return formatLookup(context.tagNames, value);
    case 'overcooked_kitchen.meal_items.meal_id':
    case 'overcooked_kitchen.meal_item_ratings.meal_id':
      return formatLookup(context.mealNames, value);
    case 'tag_manager.tool_tags.tool_id':
      return getToolDisplayText(String(value));
    case 'tag_manager.tool_tags.tag_id':
      return formatLookup(context.tagNames, value);
    case 'tag_manager.tool_tags.category_id':
      return getToolCategoryName(String(row?.tool_id ?? ''), value);
    case 'app_config.sync_config.networkType':
      return findLabel(SYNC_NETWORK_TYPE_OPTIONS, value) ?? String(value);
    case 'app_config.sync_config.lastSyncTime':
      return formatEpoch(value, 'datetime');
    case 'app_config.obj_store_config.type':
      return findLabel(OBJ_STORE_TYPE_OPTIONS, value) ?? String(value);
    case 'app_config.settings.theme_mode':
      return findLabel(THEME_MODE_OPTIONS, value) ?? String(value);
    case 'app_config.settings.default_tool_id':
      return getToolDisplayText(String(value));
    default:
      break;
  }

  if (toolId === 'work_log' && sectionKey === 'operation_logs' && fieldKey === 'target_id') {
    if (Number(row?.target_type) === 1) {
      return formatLookup(context.timeEntryNames, value);
    }
    return formatLookup(context.taskNames, value);
  }

  if (fieldKey === 'day_key') {
    return formatDayKey(value);
  }
  if (fieldKey.endsWith('_at')) {
    return formatEpoch(value, 'datetime');
  }
  if (fieldKey.includes('date')) {
    return formatEpoch(value, 'date');
  }
  return String(value);
}

export function resolveFieldEditorMeta({
  toolId,
  sectionKey,
  fieldKey,
  value,
  row,
  context,
}: FieldEditorMetaArgs): FieldEditorMeta {
  const fallbackType: 'string' | 'number' = typeof value === 'number' ? 'number' : 'string';

  const selectOptions = (() => {
    switch (`${toolId}.${sectionKey}.${fieldKey}`) {
      case 'work_log.tasks.status':
        return { options: WORK_TASK_STATUS_OPTIONS, valueType: 'number' as const };
      case 'work_log.time_entries.task_id':
      case 'work_log.task_tags.task_id':
        return {
          options: makeOptionsFromMap(context.taskNames, 'number'),
          valueType: 'number' as const,
        };
      case 'work_log.task_tags.tag_id':
        return {
          options: getTagOptionsForContext(context, 'work_log', getSectionCategoryId(sectionKey)),
          valueType: 'number' as const,
        };
      case 'work_log.operation_logs.operation_type':
        return { options: OPERATION_TYPE_OPTIONS, valueType: 'number' as const };
      case 'work_log.operation_logs.target_type':
        return { options: TARGET_TYPE_OPTIONS, valueType: 'number' as const };
      case 'stockpile_assistant.consumptions.item_id':
      case 'stockpile_assistant.item_tags.item_id':
        return {
          options: makeOptionsFromMap(context.stockItemNames, 'number'),
          valueType: 'number' as const,
        };
      case 'stockpile_assistant.item_tags.tag_id':
        return {
          options: getTagOptionsForContext(context, 'stockpile_assistant', null),
          valueType: 'number' as const,
        };
      case 'overcooked_kitchen.recipes.type_tag_id':
        return {
          options: getTagOptionsForContext(context, 'overcooked_kitchen', 'dish_type'),
          valueType: 'number' as const,
        };
      case 'overcooked_kitchen.recipe_ingredient_tags.recipe_id':
      case 'overcooked_kitchen.recipe_sauce_tags.recipe_id':
      case 'overcooked_kitchen.recipe_flavor_tags.recipe_id':
      case 'overcooked_kitchen.wish_items.recipe_id':
      case 'overcooked_kitchen.meal_items.recipe_id':
      case 'overcooked_kitchen.meal_item_ratings.recipe_id':
        return {
          options: makeOptionsFromMap(context.recipeNames, 'number'),
          valueType: 'number' as const,
        };
      case 'overcooked_kitchen.recipe_ingredient_tags.tag_id':
        return {
          options: getTagOptionsForContext(context, 'overcooked_kitchen', 'ingredient'),
          valueType: 'number' as const,
        };
      case 'overcooked_kitchen.recipe_sauce_tags.tag_id':
        return {
          options: getTagOptionsForContext(context, 'overcooked_kitchen', 'sauce'),
          valueType: 'number' as const,
        };
      case 'overcooked_kitchen.recipe_flavor_tags.tag_id':
        return {
          options: getTagOptionsForContext(context, 'overcooked_kitchen', 'flavor'),
          valueType: 'number' as const,
        };
      case 'overcooked_kitchen.meals.meal_tag_id':
        return {
          options: getTagOptionsForContext(context, 'overcooked_kitchen', 'meal_slot'),
          valueType: 'number' as const,
        };
      case 'overcooked_kitchen.meal_items.meal_id':
      case 'overcooked_kitchen.meal_item_ratings.meal_id':
        return {
          options: makeOptionsFromMap(context.mealNames, 'number'),
          valueType: 'number' as const,
        };
      case 'tag_manager.tool_tags.tool_id':
        return {
          options: context.toolOptions,
          valueType: 'string' as const,
        };
      case 'tag_manager.tool_tags.category_id':
        return {
          options: context.categoryOptionsByToolId[String(row?.tool_id ?? '')] ?? [],
          valueType: 'string' as const,
        };
      case 'tag_manager.tool_tags.tag_id': {
        const toolKey = String(row?.tool_id ?? '');
        const categoryKey = typeof row?.category_id === 'string' ? row.category_id : null;
        return {
          options: getTagOptionsForContext(context, toolKey, categoryKey),
          valueType: 'number' as const,
        };
      }
      case 'app_config.sync_config.networkType':
        return {
          options: SYNC_NETWORK_TYPE_OPTIONS,
          valueType: 'number' as const,
        };
      case 'app_config.obj_store_config.type':
        return {
          options: OBJ_STORE_TYPE_OPTIONS,
          valueType: 'string' as const,
        };
      case 'app_config.settings.theme_mode':
        return {
          options: THEME_MODE_OPTIONS,
          valueType: 'string' as const,
        };
      case 'app_config.settings.default_tool_id':
        return {
          options: context.toolOptions,
          valueType: 'string' as const,
        };
      default:
        break;
    }

    if (toolId === 'work_log' && sectionKey === 'operation_logs' && fieldKey === 'target_id') {
      if (Number(row?.target_type) === 1) {
        return {
          options: makeOptionsFromMap(context.timeEntryNames, 'number'),
          valueType: 'number' as const,
        };
      }
      return {
        options: makeOptionsFromMap(context.taskNames, 'number'),
        valueType: 'number' as const,
      };
    }

    return { options: [] as RelationOption[], valueType: fallbackType };
  })();

  if (selectOptions.options.length > 0) {
    return {
      kind: 'select',
      valueType: selectOptions.valueType,
      options: selectOptions.options,
    };
  }

  return {
    kind: 'input',
    valueType: fallbackType,
    options: [],
  };
}

export function coerceEditorValue(meta: FieldEditorMeta, value: string) {
  if (meta.valueType === 'number') {
    return value === '' ? null : Number(value);
  }
  return value;
}

export function formatSyncDecisionLabel(decision: string) {
  return SYNC_DECISION_LABELS[decision] ?? decision;
}
