import { DASHBOARD_PILL_BUTTON_MD } from '@/lib/button-styles';

export default function NotFound() {
  return (
    <div className="rounded-4xl border border-slate-200/80 bg-white/85 px-6 py-16 text-center shadow-panel">
      <h1 className="text-2xl font-semibold text-ink">页面不存在</h1>
      <p className="mt-3 text-sm text-slate-600">可能是同步用户尚未创建，或者后端暂时不可用。</p>
      <a
        href="/users"
        className={`mt-6 ${DASHBOARD_PILL_BUTTON_MD} bg-brand-700 text-white hover:bg-brand-800`}
      >
        返回同步用户目录
      </a>
    </div>
  );
}
