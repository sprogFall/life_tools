import { describe, expect, it } from 'vitest';

import { buildRelationContext, formatFriendlyValue, resolveFieldEditorMeta } from '@/lib/tool-relations';
import type { DashboardUserDetailResponse } from '@/lib/types';

const detail: DashboardUserDetailResponse = {
  success: true,
  user: {
    user_id: 'u1',
    display_name: '主账号',
    notes: '',
    is_enabled: true,
    created_at_ms: 1,
    updated_at_ms: 2,
    last_seen_at_ms: 3,
    snapshot: {
      has_snapshot: true,
      server_revision: 2,
      updated_at_ms: 4,
      tool_count: 4,
      tool_ids: ['work_log', 'stockpile_assistant', 'tag_manager', 'overcooked_kitchen'],
      total_item_count: 12,
      tool_summaries: [],
    },
  },
  snapshot: {
    has_snapshot: true,
    server_revision: 2,
    updated_at_ms: 4,
    tool_count: 4,
    tool_ids: ['work_log', 'stockpile_assistant', 'tag_manager', 'overcooked_kitchen'],
    total_item_count: 12,
    tool_summaries: [],
    tools_data: {
      tag_manager: {
        version: 1,
        data: {
          tags: [
            { id: 11, name: '项目A' },
            { id: 12, name: '厨房菜谱' },
          ],
          tool_tags: [
            { tool_id: 'work_log', tag_id: 11, category_id: 'affiliation' },
          ],
        },
      },
      work_log: {
        version: 1,
        data: {
          tasks: [
            { id: 1, title: '整理周报', status: 1 },
            { id: 2, title: '回访异常数据', status: 0 },
          ],
          time_entries: [
            { id: 101, task_id: 1, minutes: 60, content: '完成文案整理' },
          ],
          task_tags: [{ task_id: 1, tag_id: 11 }],
          operation_logs: [{ id: 1, operation_type: 1, target_type: 0, target_id: 1 }],
        },
      },
      stockpile_assistant: {
        version: 2,
        data: {
          items: [{ id: 7, name: '牛奶' }],
          consumptions: [{ id: 8, item_id: 7, quantity: 1 }],
          item_tags: [],
        },
      },
      overcooked_kitchen: {
        version: 3,
        data: {
          recipes: [{ id: 31, name: '番茄炒蛋', type_tag_id: 12 }],
          recipe_ingredient_tags: [{ recipe_id: 31, tag_id: 12 }],
          recipe_sauce_tags: [],
          recipe_flavor_tags: [],
          wish_items: [{ id: 40, recipe_id: 31 }],
          meals: [{ id: 41, day_key: 20260307 }],
          meal_items: [{ meal_id: 41, recipe_id: 31 }],
          meal_item_ratings: [],
        },
      },
    },
  },
  recent_records: [],
};

describe('tool-relations', () => {
  it('能把跨工具和同工具的 id 解析为友好文案', () => {
    const context = buildRelationContext(detail);

    expect(formatFriendlyValue({ toolId: 'work_log', sectionKey: 'time_entries', fieldKey: 'task_id', value: 1, context })).toContain('整理周报');
    expect(formatFriendlyValue({ toolId: 'stockpile_assistant', sectionKey: 'consumptions', fieldKey: 'item_id', value: 7, context })).toContain('牛奶');
    expect(formatFriendlyValue({ toolId: 'work_log', sectionKey: 'task_tags', fieldKey: 'tag_id', value: 11, context })).toContain('项目A');
    expect(formatFriendlyValue({ toolId: 'overcooked_kitchen', sectionKey: 'wish_items', fieldKey: 'recipe_id', value: 31, context })).toContain('番茄炒蛋');
  });

  it('能为选择字段生成 options，而不是让用户手填 id', () => {
    const context = buildRelationContext(detail);

    const taskField = resolveFieldEditorMeta({
      toolId: 'work_log',
      sectionKey: 'time_entries',
      fieldKey: 'task_id',
      value: 1,
      context,
    });
    expect(taskField.kind).toBe('select');
    expect(taskField.options.map((item) => item.label)).toContain('整理周报');

    const statusField = resolveFieldEditorMeta({
      toolId: 'work_log',
      sectionKey: 'tasks',
      fieldKey: 'status',
      value: 1,
      context,
    });
    expect(statusField.kind).toBe('select');
    expect(statusField.options.map((item) => item.label)).toContain('进行中');
  });
});
