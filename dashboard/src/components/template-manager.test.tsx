import React from 'react';
import { cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { TemplateManager } from '@/components/template-manager';
import { fetchDashboardTool, updateDashboardTool } from '@/lib/api';
import type { WorkPhotoTemplateData } from '@/lib/types';

vi.mock('@/lib/api', () => ({
  fetchDashboardTool: vi.fn(),
  updateDashboardTool: vi.fn(),
}));

const fetchDashboardToolMock = vi.mocked(fetchDashboardTool);
const updateDashboardToolMock = vi.mocked(updateDashboardTool);

function createDataTransfer() {
  const data = new Map<string, string>();
  return {
    effectAllowed: '',
    dropEffect: '',
    setData: vi.fn((type: string, value: string) => {
      data.set(type, value);
    }),
    getData: vi.fn((type: string) => data.get(type) ?? ''),
  } as unknown as DataTransfer;
}

const templateData: WorkPhotoTemplateData = {
  templates: [
    {
      id: 10,
      name: '交付拍摄模板',
      sort_index: 0,
      is_archived: 0,
      created_at: 1,
      updated_at: 1,
    },
  ],
  hierarchy_levels: [
    {
      id: 100,
      template_id: 10,
      parent_level_id: null,
      name: '楼栋',
      sort_index: 0,
      is_required: 1,
      is_archived: 0,
      created_at: 1,
      updated_at: 1,
    },
    {
      id: 101,
      template_id: 10,
      parent_level_id: 100,
      name: '房间',
      sort_index: 0,
      is_required: 1,
      is_archived: 0,
      created_at: 1,
      updated_at: 1,
    },
  ],
  hierarchy_options: [
    {
      id: 1000,
      level_id: 100,
      parent_option_id: null,
      name: 'A栋',
      sort_index: 0,
      is_archived: 0,
      created_at: 1,
      updated_at: 1,
    },
  ],
  capture_items: [
    {
      id: 200,
      template_id: 10,
      parent_level_id: 101,
      name: '门头照',
      sort_index: 0,
      min_count: 1,
      max_count: null,
      is_archived: 0,
      created_at: 1,
      updated_at: 1,
    },
  ],
};

beforeEach(() => {
  fetchDashboardToolMock.mockResolvedValue({
    success: true,
    tool: {
      tool_id: 'work_photo',
      version: 2,
      summary: {
        tool_id: 'work_photo',
        version: 2,
        total_items: 4,
        section_counts: {},
      },
      data: structuredClone(templateData),
    },
  });
  updateDashboardToolMock.mockResolvedValue({
    success: true,
    tool: {
      tool_id: 'work_photo',
      version: 2,
      summary: {
        tool_id: 'work_photo',
        version: 2,
        total_items: 4,
        section_counts: {},
      },
      data: structuredClone(templateData),
    },
  });
  vi.spyOn(Date, 'now').mockReturnValue(9999);
});

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

describe('TemplateManager', () => {
  it('按目录树展示模板层级和拍摄项', async () => {
    render(<TemplateManager userId="u1" />);

    expect(await screen.findByText('交付拍摄模板')).toBeInTheDocument();
    expect(screen.getAllByRole('heading', { name: /树形配置/ }).length).toBeGreaterThan(0);
    expect(screen.getByRole('tree', { name: '模板目录和拍摄项' })).toBeInTheDocument();

    const buildingNode = screen.getByTestId('work-photo-level-100');
    const roomNode = screen.getByTestId('work-photo-level-101');
    const captureNode = screen.getByTestId('work-photo-item-200');

    expect(within(buildingNode).getByDisplayValue('楼栋')).toBeInTheDocument();
    expect(within(roomNode).getByDisplayValue('房间')).toBeInTheDocument();
    expect(within(captureNode).getByDisplayValue('门头照')).toBeInTheDocument();
    expect(captureNode).toHaveTextContent('楼栋 / 房间');
    expect(screen.queryByLabelText('归属目录')).not.toBeInTheDocument();
    expect(screen.queryByText('目录选项')).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: '添加选项' })).not.toBeInTheDocument();
  });

  it('支持在指定目录下快速新增拍摄项，并在点击保存后同步', async () => {
    render(<TemplateManager userId="u1" />);

    const roomNode = await screen.findByTestId('work-photo-level-101');
    fireEvent.click(within(roomNode).getByRole('button', { name: '在房间下添加拍摄项' }));

    expect(updateDashboardToolMock).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole('button', { name: '保存配置' }));

    await waitFor(() => {
      expect(updateDashboardToolMock).toHaveBeenCalled();
    });

    const saved = updateDashboardToolMock.mock.calls.at(-1)?.[0].data as unknown as WorkPhotoTemplateData;
    expect(saved.hierarchy_options).toEqual(templateData.hierarchy_options);
    expect(saved.capture_items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          template_id: 10,
          parent_level_id: 101,
          name: '新拍摄项',
          sort_index: 1,
          min_count: 1,
          max_count: null,
        }),
      ]),
    );
  });

  it('支持拖拽拍摄项到根目录，并在点击保存后同步', async () => {
    render(<TemplateManager userId="u1" />);

    const captureNode = await screen.findByTestId('work-photo-item-200');
    const rootDropZone = screen.getByTestId('work-photo-root-drop-zone');
    const dataTransfer = createDataTransfer();

    fireEvent.dragStart(captureNode, { dataTransfer });
    fireEvent.drop(rootDropZone, { dataTransfer });

    expect(updateDashboardToolMock).not.toHaveBeenCalled();
    expect(screen.getByTestId('work-photo-item-200')).toHaveTextContent('根目录');

    fireEvent.click(screen.getByRole('button', { name: '保存配置' }));

    await waitFor(() => {
      expect(updateDashboardToolMock).toHaveBeenCalled();
    });

    const saved = updateDashboardToolMock.mock.calls.at(-1)?.[0].data as unknown as WorkPhotoTemplateData;
    expect(saved.capture_items).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 200,
          parent_level_id: null,
        }),
      ]),
    );
  });

  it('支持拖拽目录到根目录，并在点击保存后同步', async () => {
    render(<TemplateManager userId="u1" />);

    const roomNode = await screen.findByTestId('work-photo-level-101');
    const rootDropZone = screen.getByTestId('work-photo-root-drop-zone');
    const dataTransfer = createDataTransfer();

    fireEvent.dragStart(roomNode, { dataTransfer });
    fireEvent.drop(rootDropZone, { dataTransfer });

    expect(updateDashboardToolMock).not.toHaveBeenCalled();
    expect(screen.getByTestId('work-photo-level-101')).toHaveTextContent('根目录');

    fireEvent.click(screen.getByRole('button', { name: '保存配置' }));

    await waitFor(() => {
      expect(updateDashboardToolMock).toHaveBeenCalled();
    });

    const saved = updateDashboardToolMock.mock.calls.at(-1)?.[0].data as unknown as WorkPhotoTemplateData;
    expect(saved.hierarchy_levels).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          id: 101,
          parent_level_id: null,
        }),
      ]),
    );
  });
});
