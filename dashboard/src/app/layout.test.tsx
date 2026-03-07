import { describe, expect, it, vi } from 'vitest';
import { renderToStaticMarkup } from 'react-dom/server';

vi.mock('next/font/google', () => ({
  Fira_Code: () => ({ variable: 'font-heading' }),
  Fira_Sans: () => ({ variable: 'font-body' }),
}));

import RootLayout from '@/app/layout';

describe('RootLayout', () => {
  it('只展示面向用户的导航信息，不展示开发构建说明', () => {
    const html = renderToStaticMarkup(
      <RootLayout>
        <div>页面主体</div>
      </RootLayout>,
    );

    expect(html).toContain('Life Tools');
    expect(html).toContain('Dashboard');
    expect(html).toContain('同步用户');
    expect(html).not.toContain('npm run build');
    expect(html).not.toContain('NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_API_BASE_URL');
    expect(html).not.toContain('静态部署约定');
  });
});
