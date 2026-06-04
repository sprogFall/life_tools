import React from 'react';
import { cleanup, render, screen } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { TemplatesScreen } from '@/components/templates-screen';
import { fetchDashboardUsers } from '@/lib/api';

vi.mock('@/lib/api', () => ({
  fetchDashboardUsers: vi.fn(),
}));

const fetchDashboardUsersMock = vi.mocked(fetchDashboardUsers);

beforeEach(() => {
  fetchDashboardUsersMock.mockResolvedValue([]);
});

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
});

describe('TemplatesScreen', () => {
  it('使用中文展示外拍助手模板树形配置入口', async () => {
    render(<TemplatesScreen />);

    expect(await screen.findByRole('heading', { name: '外拍助手模板管理' })).toBeInTheDocument();
    expect(screen.getByText('树形配置工作台')).toBeInTheDocument();
    expect(screen.queryByText('Work Photo Templates')).not.toBeInTheDocument();
  });
});
