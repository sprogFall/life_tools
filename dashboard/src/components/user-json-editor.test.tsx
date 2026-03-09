import React from 'react';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { UserJsonEditor } from '@/components/user-json-editor';
import type {
  DashboardToolSnapshot,
  SaveDashboardSnapshotInput,
  SaveDashboardToolInput,
} from '@/lib/types';

afterEach(() => cleanup());

const toolsData: Record<string, DashboardToolSnapshot> = {
  work_log: {
    version: 1,
    data: {
      tasks: [
        {
          id: 1,
          title: '整理周报',
        },
      ],
    },
  },
  app_config: {
    version: 1,
    data: {
      ai_config: {
        baseUrl: 'https://api.openai.com/v1',
        model: 'gpt-4.1',
      },
    },
  },
};

describe('UserJsonEditor', () => {
  it('为长文案按钮提供可换行样式，避免在窄屏下溢出按钮', () => {
    render(
      <UserJsonEditor
        userId="u1"
        toolsData={toolsData}
        saveSnapshotAction={vi.fn().mockResolvedValue({ success: true, message: '已保存' })}
      />,
    );

    const saveButton = screen.getByRole('button', { name: '保存 JSON 到后端' });
    const resetButton = screen.getByRole('button', { name: '重置 JSON 草稿' });

    expect(saveButton.className).toContain('max-w-full');
    expect(saveButton.className).toContain('whitespace-normal');
    expect(saveButton.className).toContain('break-words');
    expect(resetButton.className).toContain('max-w-full');
    expect(screen.getByRole('button', { name: '全部快照' }).className).toContain('min-w-0');
  });

  it('可以展示格式化后的用户快照 JSON，并在保存时传递解析后的对象', async () => {
    const saveSnapshotAction = vi.fn<
      (input: SaveDashboardSnapshotInput) => Promise<{ success: boolean; message: string }>
    >().mockResolvedValue({ success: true, message: '已保存' });

    render(
      <UserJsonEditor
        userId="u1"
        toolsData={toolsData}
        saveSnapshotAction={saveSnapshotAction}
      />,
    );

    const editor = screen.getByRole('textbox', { name: '同步快照 JSON' });
    expect(editor).toHaveValue(JSON.stringify(toolsData, null, 2));

    fireEvent.change(editor, {
      target: {
        value: JSON.stringify(
          {
            work_log: {
              version: 1,
              data: {
                tasks: [{ id: 1, title: '直接改 JSON 后的标题' }],
              },
            },
            app_config: toolsData.app_config,
          },
          null,
          2,
        ),
      },
    });

    fireEvent.click(screen.getByRole('button', { name: '保存 JSON 到后端' }));

    await waitFor(() =>
      expect(saveSnapshotAction).toHaveBeenCalledWith({
        userId: 'u1',
        toolsData: {
          work_log: {
            version: 1,
            data: {
              tasks: [{ id: 1, title: '直接改 JSON 后的标题' }],
            },
          },
          app_config: toolsData.app_config,
        },
      }),
    );
  });

  it('支持切到单工具 JSON 模式，并单独保存当前工具', async () => {
    const saveSnapshotAction = vi.fn().mockResolvedValue({ success: true, message: '已保存' });
    const saveToolAction = vi.fn<
      (input: SaveDashboardToolInput) => Promise<{ success: boolean; message: string }>
    >().mockResolvedValue({ success: true, message: '单工具已保存' });

    render(
      <UserJsonEditor
        userId="u1"
        toolsData={toolsData}
        initialToolId="app_config"
        saveSnapshotAction={saveSnapshotAction}
        saveToolAction={saveToolAction}
      />,
    );

    const editor = screen.getByRole('textbox', { name: '当前工具 JSON' });
    expect(editor).toHaveValue(JSON.stringify(toolsData.app_config, null, 2));

    fireEvent.change(editor, {
      target: {
        value: JSON.stringify(
          {
            version: 1,
            data: {
              ai_config: {
                baseUrl: 'https://api.openai.com/v1',
                model: 'gpt-5-mini',
              },
            },
          },
          null,
          2,
        ),
      },
    });

    fireEvent.click(screen.getByRole('button', { name: '保存当前工具 JSON' }));

    await waitFor(() =>
      expect(saveToolAction).toHaveBeenCalledWith({
        userId: 'u1',
        toolId: 'app_config',
        version: 1,
        data: {
          ai_config: {
            baseUrl: 'https://api.openai.com/v1',
            model: 'gpt-5-mini',
          },
        },
      }),
    );
    expect(saveSnapshotAction).not.toHaveBeenCalled();
  });

  it('JSON 非法时只展示紧凑错误，不占用大块空间', async () => {
    const saveSnapshotAction = vi.fn().mockResolvedValue({ success: true, message: '已保存' });

    render(
      <UserJsonEditor
        userId="u1"
        toolsData={toolsData}
        saveSnapshotAction={saveSnapshotAction}
      />,
    );

    fireEvent.change(screen.getByRole('textbox', { name: '同步快照 JSON' }), {
      target: { value: '{ invalid json' },
    });

    fireEvent.click(screen.getByRole('button', { name: '保存 JSON 到后端' }));

    await waitFor(() => expect(screen.getByRole('alert')).toHaveTextContent('JSON 解析失败'));
    expect(screen.getByRole('alert').textContent).not.toContain('\n');
    expect(saveSnapshotAction).not.toHaveBeenCalled();
  });
});
