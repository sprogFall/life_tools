import type { Metadata } from 'next';
import { Fira_Code, Fira_Sans } from 'next/font/google';

import '@/app/globals.css';
import { getDashboardBuildInfo } from '@/lib/build-info';

const bodyFont = Fira_Sans({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  variable: '--font-body',
});
const headingFont = Fira_Code({
  subsets: ['latin'],
  weight: ['400', '500', '600', '700'],
  variable: '--font-heading',
});

export const metadata: Metadata = {
  title: 'Life Tools Dashboard',
  description: '面向同步用户的数据管理台',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const buildInfo = getDashboardBuildInfo();

  return (
    <html lang="zh-CN">
      <head>
        <meta name="life-tools-dashboard-git-version" content={buildInfo.gitVersion} />
        {buildInfo.buildTime ? <meta name="life-tools-dashboard-build-time" content={buildInfo.buildTime} /> : null}
      </head>
      <body className={`${bodyFont.variable} ${headingFont.variable} bg-mist font-sans text-ink`}>
        <div className="min-h-screen px-4 py-6 md:px-6 xl:px-8">
          <div className="mx-auto grid min-h-[calc(100vh-3rem)] max-w-[1600px] gap-6 xl:grid-cols-[280px_1fr]">
            <aside className="flex h-full flex-col rounded-[2rem] border border-white/60 bg-slate-950 px-6 py-8 text-white shadow-panel">
              <p className="font-mono text-sm uppercase tracking-[0.28em] text-brand-200">Life Tools</p>
              <h1 className="mt-4 text-3xl font-semibold leading-tight">Dashboard</h1>
              <p className="mt-3 text-sm leading-6 text-white/70">现代化的数据管理台，直接面向同步用户进行审阅、维护和保存。</p>
              <nav className="mt-8 space-y-3">
                <a href="/" className="flex items-center justify-between rounded-2xl bg-white/8 px-4 py-3 text-sm font-medium transition hover:bg-white/12">
                  <span>概览</span>
                  <span className="font-mono text-xs text-white/50">01</span>
                </a>
                <a href="/users" className="flex items-center justify-between rounded-2xl bg-white/8 px-4 py-3 text-sm font-medium transition hover:bg-white/12">
                  <span>同步用户</span>
                  <span className="font-mono text-xs text-white/50">02</span>
                </a>
              </nav>
              <section aria-label="当前前端版本" className="mt-10 rounded-2xl border border-white/10 bg-white/5 px-4 py-4 text-white/75 xl:mt-auto">
                <p className="font-mono text-[11px] uppercase tracking-[0.24em] text-white/45">前端版本</p>
                <p className="mt-2 break-all font-mono text-sm font-semibold text-white">{buildInfo.gitVersion}</p>
                {buildInfo.buildTime ? (
                  <time className="mt-2 block break-all font-mono text-[11px] text-white/55" dateTime={buildInfo.buildTime}>
                    构建于 {buildInfo.buildTime}
                  </time>
                ) : null}
                <a
                  href="/dashboard-version.json"
                  className="mt-3 inline-flex items-center rounded-full border border-white/12 px-3 py-1.5 text-xs font-medium text-white transition hover:border-white/20 hover:bg-white/8"
                >
                  查看版本文件
                </a>
              </section>
            </aside>
            <main className="rounded-[2rem] border border-white/70 bg-white/70 p-5 shadow-panel backdrop-blur md:p-8">
              {children}
            </main>
          </div>
        </div>
      </body>
    </html>
  );
}
