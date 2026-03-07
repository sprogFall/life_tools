import React from 'react';
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { UserJsonEditor } from '@/components/user-json-editor';
import type { DashboardToolSnapshot, SaveDashboardSnapshotInput } from '@/lib/types';

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
};

describe('UserJsonEditor', () => {
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
        },
      }),
    );
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
