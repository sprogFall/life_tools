import { afterEach, describe, expect, it, vi } from 'vitest';
import { renderToStaticMarkup } from 'react-dom/server';

vi.mock('next/font/google', () => ({
  Fira_Code: () => ({ variable: 'font-heading' }),
  Fira_Sans: () => ({ variable: 'font-body' }),
}));

import RootLayout from '@/app/layout';

const originalGitVersion = process.env.NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_GIT_VERSION;
const originalBuildTime = process.env.NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_BUILD_TIME;

afterEach(() => {
  if (originalGitVersion === undefined) {
    delete process.env.NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_GIT_VERSION;
  } else {
    process.env.NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_GIT_VERSION = originalGitVersion;
  }

  if (originalBuildTime === undefined) {
    delete process.env.NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_BUILD_TIME;
  } else {
    process.env.NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_BUILD_TIME = originalBuildTime;
  }
});

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

  it('展示当前前端 git 版本和构建时间，便于核对部署产物', () => {
    process.env.NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_GIT_VERSION = '0a9d5d061cfb';
    process.env.NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_BUILD_TIME = '2026-03-08T12:34:56Z';

    const html = renderToStaticMarkup(
      <RootLayout>
        <div>页面主体</div>
      </RootLayout>,
    );

    expect(html).toContain('前端版本');
    expect(html).toContain('0a9d5d061cfb');
    expect(html).toContain('2026-03-08T12:34:56Z');
    expect(html).toContain('name="life-tools-dashboard-git-version"');
    expect(html).toContain('content="0a9d5d061cfb"');
    expect(html).toContain('name="life-tools-dashboard-build-time"');
    expect(html).toContain('content="2026-03-08T12:34:56Z"');
  });
});
