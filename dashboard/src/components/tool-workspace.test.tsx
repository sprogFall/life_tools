import React from 'react';
import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ToolWorkspace } from '@/components/tool-workspace';
import { buildRelationContext } from '@/lib/tool-relations';
import type { DashboardToolPayload, DashboardUserDetailResponse } from '@/lib/types';

afterEach(() => cleanup());

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
      server_revision: 1,
      updated_at_ms: 4,
      tool_count: 1,
      tool_ids: ['work_log'],
      total_item_count: 2,
      tool_summaries: [],
    },
  },
  snapshot: {
    has_snapshot: true,
    server_revision: 1,
    updated_at_ms: 4,
    tool_count: 2,
    tool_ids: ['work_log', 'tag_manager'],
    total_item_count: 4,
    tool_summaries: [],
    tools_data: {
      work_log: {
        version: 1,
        data: {
          tasks: [
            {
              id: 1,
              title: '整理周报',
              description: '补充风险说明',
              status: 1,
              estimated_minutes: 60,
              sort_index: 1,
              is_pinned: true,
              created_at: 1731000000000,
              updated_at: 1731000001000,
            },
            {
              id: 2,
              title: '需求拆分',
              description: '重新归类历史工时',
              status: 0,
              estimated_minutes: 90,
              sort_index: 2,
              is_pinned: false,
              created_at: 1731000002000,
              updated_at: 1731000003000,
            },
          ],
          time_entries: [
            {
              id: 1,
              task_id: 1,
              minutes: 60,
              content: '完成文案整理',
              work_date: 1731000000000,
              created_at: 1731000000000,
              updated_at: 1731000001000,
            },
            {
              id: 2,
              task_id: 1,
              minutes: 30,
              content: '补录会议纪要',
              work_date: 1731086400000,
              created_at: 1731086400000,
              updated_at: 1731086401000,
            },
          ],
          operation_logs: [],
          task_tags: [
            { task_id: 1, tag_id: 10 },
            { task_id: 2, tag_id: 11 },
          ],
        },
      },
      tag_manager: {
        version: 1,
        data: {
          tags: [
            { id: 10, name: '项目A' },
            { id: 11, name: '项目B' },
          ],
          tool_tags: [],
        },
      },
    },
  },
  recent_records: [],
};

const tool: DashboardToolPayload = {
  tool_id: 'work_log',
  version: 1,
  summary: {
    tool_id: 'work_log',
    version: 1,
    total_items: 4,
    section_counts: {
      tasks: 2,
      time_entries: 2,
      operation_logs: 0,
    },
  },
  data: detail.snapshot.tools_data.work_log.data,
};

describe('ToolWorkspace', () => {
  it('渲染友好关联文案，并为关联字段提供选择器', () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    expect(screen.getByText('工作记录')).toBeInTheDocument();
    expect(screen.getByText('共管理 4 条记录')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'tasks (2)' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'time_entries (2)' })).toBeInTheDocument();
    expect(screen.getAllByRole('button', { name: '保存' }).length).toBeGreaterThan(0);

    const timeEntriesTab = screen.getByRole('button', { name: 'time_entries (2)' });
    fireEvent.click(timeEntriesTab);

    expect(screen.getAllByText('整理周报').length).toBeGreaterThan(0);
    expect(screen.getByRole('combobox', { name: '任务' })).toHaveDisplayValue('整理周报');
  });

  it('支持在记录编辑器内直接保存当前修改', async () => {
    const saveToolAction = vi.fn().mockResolvedValue({ success: true, message: 'ok' });
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={saveToolAction}
      />,
    );

    const titleInput = screen.getByRole('textbox', { name: '标题' });
    fireEvent.change(titleInput, { target: { value: '整理周报（已更新）' } });

    expect(screen.queryByRole('button', { name: '保存到草稿' })).not.toBeInTheDocument();

    const commitButton = screen.getAllByRole('button', { name: '保存' })[1];
    expect(commitButton).toBeEnabled();

    fireEvent.click(commitButton);

    await waitFor(() => {
      expect(saveToolAction).toHaveBeenCalled();
    });

    expect(saveToolAction).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'u1',
        toolId: 'work_log',
        version: 1,
        data: expect.objectContaining({
          tasks: expect.arrayContaining([expect.objectContaining({ id: 1, title: '整理周报（已更新）' })]),
        }),
      }),
    );
  });

  it('对敏感字段使用只读限制，例如主键 id 不允许直接修改', () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    expect(screen.getByRole('textbox', { name: '标题' })).toHaveValue('整理周报');
    expect(screen.queryByRole('spinbutton', { name: 'ID' })).not.toBeInTheDocument();
    expect(screen.getByLabelText('创建时间')).toBeDisabled();
  });

  it('列表中隐藏原始值提示和冗余编辑列，只保留实际业务字段', () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    expect(screen.queryByText('编辑记录')).not.toBeInTheDocument();
    expect(screen.queryByText('操作')).not.toBeInTheDocument();
    expect(screen.queryByText(/原始值：/)).not.toBeInTheDocument();
  });

  it('不再展示直接进入工时树按钮，避免无效快捷入口', () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    expect(screen.queryByRole('button', { name: '直接进入工时树' })).not.toBeInTheDocument();
  });

  it('工时归属改为独立画布模态入口，并移除内联树状切换', () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: 'time_entries (2)' }));

    expect(screen.getByRole('button', { name: '打开工时归属画布' })).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: '树状展示' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: '列表展示' })).not.toBeInTheDocument();
  });

  it('画布支持按任务状态和标签多选筛选任务节点', () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: 'time_entries (2)' }));
    fireEvent.click(screen.getByRole('button', { name: '打开工时归属画布' }));

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });

    fireEvent.click(within(dialog).getByRole('button', { name: '按任务状态筛选' }));
    fireEvent.click(within(dialog).getByRole('checkbox', { name: '进行中' }));
    expect(within(dialog).getByRole('group', { name: '工时画布节点 整理周报' })).toBeInTheDocument();
    expect(within(dialog).queryByRole('group', { name: '工时画布节点 需求拆分' })).not.toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: /按任务状态筛选/ })).toHaveTextContent('进行中');

    fireEvent.click(within(dialog).getByRole('button', { name: '清空状态筛选' }));
    fireEvent.click(within(dialog).getByRole('button', { name: '按任务标签筛选' }));
    fireEvent.click(within(dialog).getByRole('checkbox', { name: '项目B' }));
    expect(within(dialog).queryByRole('group', { name: '工时画布节点 整理周报' })).not.toBeInTheDocument();
    expect(within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' })).toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: /按任务标签筛选/ })).toHaveTextContent('项目B');
  });

  it('移除画布内保存到草稿按钮，仅保留直白的保存按钮', () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: 'time_entries (2)' }));
    fireEvent.click(screen.getByRole('button', { name: '打开工时归属画布' }));

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    const sourceGroup = within(dialog).getByRole('group', { name: '工时画布节点 整理周报' });
    const targetGroup = within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' });
    const entryCard = within(dialog).getByRole('button', { name: '工时卡片 补录会议纪要' });

    expect(within(sourceGroup).getByText('补录会议纪要')).toBeInTheDocument();

    fireEvent.dragStart(entryCard);
    fireEvent.dragOver(targetGroup);
    fireEvent.drop(targetGroup);

    expect(within(within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' })).getByText('补录会议纪要')).toBeInTheDocument();
    expect(within(within(dialog).getByRole('group', { name: '工时画布节点 整理周报' })).queryByText('补录会议纪要')).not.toBeInTheDocument();
    expect(within(dialog).getByText('已将“补录会议纪要”归属到“需求拆分”')).toBeInTheDocument();

    expect(within(dialog).queryByRole('button', { name: '保存到草稿' })).not.toBeInTheDocument();
    expect(within(dialog).queryByRole('button', { name: '提交到后端' })).not.toBeInTheDocument();
    expect(within(dialog).getByRole('button', { name: '保存' })).toBeEnabled();
  });

  it('支持在画布模态中直接保存，避免刷新后回退到旧数据', async () => {
    const saveToolAction = vi.fn().mockResolvedValue({ success: true, message: 'ok' });
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={saveToolAction}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: 'time_entries (2)' }));
    fireEvent.click(screen.getByRole('button', { name: '打开工时归属画布' }));

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    fireEvent.dragStart(within(dialog).getByRole('button', { name: '工时卡片 补录会议纪要' }));
    fireEvent.dragOver(within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' }));
    fireEvent.drop(within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' }));
    fireEvent.click(within(dialog).getByRole('button', { name: '保存' }));

    await waitFor(() => {
      expect(saveToolAction).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: 'u1',
          toolId: 'work_log',
          version: 1,
          data: expect.objectContaining({
            time_entries: expect.arrayContaining([expect.objectContaining({ id: 2, task_id: 2 })]),
          }),
        }),
      );
    });
  });


  it('取消画布内调整时不会污染当前草稿', () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: 'time_entries (2)' }));
    fireEvent.click(screen.getByRole('button', { name: '打开工时归属画布' }));

    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    const targetGroup = within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' });
    const entryCard = within(dialog).getByRole('button', { name: '工时卡片 补录会议纪要' });

    fireEvent.dragStart(entryCard);
    fireEvent.dragOver(targetGroup);
    fireEvent.drop(targetGroup);
    fireEvent.click(within(dialog).getByRole('button', { name: '取消调整' }));

    screen.getAllByRole('button', { name: '保存' }).forEach((button) => {
      expect(button).toBeDisabled();
    });

    fireEvent.click(screen.getByRole('button', { name: '打开工时归属画布' }));

    expect(
      within(screen.getByRole('dialog', { name: '工时归属整理画布' })).getByRole('group', {
        name: '工时画布节点 整理周报',
      }),
    ).toHaveTextContent('补录会议纪要');
  });


  it('保存失败时会以 alert 形式展示后端返回的详细错误', async () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={vi.fn().mockResolvedValue({
          success: false,
          message: '工时记录“补录会议纪要”的 task_id=999 未匹配到任务。可用任务：1=整理周报',
        })}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: 'time_entries (2)' }));
    fireEvent.click(screen.getByRole('button', { name: '打开工时归属画布' }));
    const dialog = screen.getByRole('dialog', { name: '工时归属整理画布' });
    fireEvent.dragStart(within(dialog).getByRole('button', { name: '工时卡片 补录会议纪要' }));
    fireEvent.dragOver(within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' }));
    fireEvent.drop(within(dialog).getByRole('group', { name: '工时画布节点 需求拆分' }));
    fireEvent.click(within(dialog).getByRole('button', { name: '保存' }));

    expect(await screen.findByRole('alert')).toHaveTextContent('工时记录“补录会议纪要”的 task_id=999 未匹配到任务。可用任务：1=整理周报');
  });


  it('移动端使用列表和编辑器双视图，点选记录后自动进入编辑器', () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    const listButton = screen.getByRole('button', { name: '列表' });
    const editorButton = screen.getByRole('button', { name: '编辑器' });

    expect(listButton).toHaveAttribute('aria-pressed', 'true');
    expect(editorButton).toHaveAttribute('aria-pressed', 'false');

    const firstRowButton = screen
      .getAllByRole('button', { name: /整理周报/ })
      .find((button) => button.textContent?.includes('补充风险说明'));

    expect(firstRowButton).toBeDefined();
    fireEvent.click(firstRowButton!);

    expect(listButton).toHaveAttribute('aria-pressed', 'false');
    expect(editorButton).toHaveAttribute('aria-pressed', 'true');
  });

  it('桌面端支持分别收起和展开列表面板与记录编辑器面板', () => {
    render(
      <ToolWorkspace
        userId="u1"
        tool={tool}
        relationContext={buildRelationContext(detail)}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    fireEvent.click(screen.getByRole('button', { name: '收起记录编辑器面板' }));

    expect(screen.queryByRole('heading', { level: 3, name: '记录编辑器' })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: '展开记录编辑器面板' })).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: '收起任务面板' }));

    expect(screen.queryByRole('heading', { level: 3, name: '任务' })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: '展开任务面板' })).toBeInTheDocument();

    fireEvent.click(screen.getByRole('button', { name: '展开记录编辑器面板' }));
    fireEvent.click(screen.getByRole('button', { name: '展开任务面板' }));

    expect(screen.getByRole('heading', { level: 3, name: '任务' })).toBeInTheDocument();
    expect(screen.getByRole('heading', { level: 3, name: '记录编辑器' })).toBeInTheDocument();
  });

  it('支持展示 app_config 这类对象型区块，并允许敏感字段眼睛开关查看', () => {
    const appConfigTool: DashboardToolPayload = {
      tool_id: 'app_config',
      version: 1,
      summary: {
        tool_id: 'app_config',
        version: 1,
        total_items: 5,
        section_counts: {
          ai_config: 1,
          sync_config: 1,
          obj_store_config: 1,
          obj_store_secrets: 1,
          settings: 1,
        },
      },
      data: {
        ai_config: {
          baseUrl: 'https://api.openai.com/v1',
          apiKey: 'sk-test',
          model: 'gpt-4.1',
          temperature: 0.7,
          maxOutputTokens: 4096,
        },
        sync_config: {
          userId: 'u1',
          serverUrl: 'https://sync.example.com',
          serverPort: 443,
          customHeaders: { Authorization: 'Bearer test' },
          allowedWifiNames: ['Office'],
          autoSyncOnStartup: true,
        },
        obj_store_config: {
          type: 'qiniu',
          bucket: 'life-tools',
          domain: 'cdn.example.com',
          uploadHost: 'https://upload.qiniup.com',
        },
        obj_store_secrets: {
          accessKey: 'ak-test',
          secretKey: 'sk-secret',
        },
        settings: {
          default_tool_id: 'work_log',
          tool_order: ['work_log', 'stockpile_assistant'],
          hidden_tool_ids: ['tag_manager'],
          theme_mode: 'dark',
        },
      },
    };

    render(
      <ToolWorkspace
        userId="u1"
        tool={appConfigTool}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    expect(screen.getByText('应用配置')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'ai_config (1)' })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'sync_config (1)' })).toBeInTheDocument();
    expect(screen.getByLabelText('Base URL')).toHaveValue('https://api.openai.com/v1');

    const apiKeyField = screen.getByRole('textbox', { name: 'API Key' });
    expect(apiKeyField).toHaveValue('••••••••');

    fireEvent.click(screen.getByRole('button', { name: '显示 API Key' }));
    expect(screen.getByRole('textbox', { name: 'API Key' })).toHaveValue('sk-test');

    fireEvent.click(screen.getByRole('button', { name: '隐藏 API Key' }));
    expect(screen.getByRole('textbox', { name: 'API Key' })).toHaveValue('••••••••');

    fireEvent.click(screen.getByRole('button', { name: '显示 API Key' }));
    expect(screen.getByRole('textbox', { name: 'API Key' })).toHaveValue('sk-test');

    fireEvent.click(screen.getByRole('button', { name: 'sync_config (1)' }));
    fireEvent.click(screen.getByRole('button', { name: 'ai_config (1)' }));
    expect(screen.getByRole('button', { name: '显示 API Key' })).toBeInTheDocument();
    expect(screen.getByRole('textbox', { name: 'API Key' })).toHaveValue('••••••••');
  });

  it('为长预览值提供完整悬浮标题，避免配置列表内容互相挤压', () => {
    const longBaseUrl = 'https://api-inference.modelscope.cn/v1/chat/completions';
    const longModel = 'deepseek-ai/DeepSeek-V3.2-Long-Preview-Value';
    const appConfigTool: DashboardToolPayload = {
      tool_id: 'app_config',
      version: 1,
      summary: {
        tool_id: 'app_config',
        version: 1,
        total_items: 5,
        section_counts: {
          ai_config: 1,
          sync_config: 1,
          obj_store_config: 1,
          obj_store_secrets: 1,
          settings: 1,
        },
      },
      data: {
        ai_config: {
          baseUrl: longBaseUrl,
          apiKey: 'sk-test',
          model: longModel,
          temperature: 0.7,
          maxOutputTokens: 102400,
        },
        sync_config: {
          userId: 'u1',
          serverUrl: 'https://sync.example.com',
          serverPort: 443,
        },
        obj_store_config: {
          type: 'qiniu',
          bucket: 'life-tools',
        },
        obj_store_secrets: {
          accessKey: 'ak-test',
          secretKey: 'sk-secret',
        },
        settings: {
          default_tool_id: 'work_log',
          tool_order: ['work_log'],
          hidden_tool_ids: [],
          theme_mode: 'dark',
        },
      },
    };

    render(
      <ToolWorkspace
        userId="u1"
        tool={appConfigTool}
        saveToolAction={vi.fn().mockResolvedValue({ success: true, message: 'ok' })}
      />,
    );

    expect(screen.getByTitle(longBaseUrl)).toBeInTheDocument();
    expect(screen.getByTitle(longModel)).toBeInTheDocument();
  });

});
