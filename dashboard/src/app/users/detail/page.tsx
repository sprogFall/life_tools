import { Suspense } from 'react';

import { UserDetailScreen } from '@/components/user-detail-screen';

export default function UserDetailPage() {
  return (
    <Suspense fallback={<div className="rounded-4xl border border-slate-200 bg-white/85 px-6 py-16 text-center text-sm text-slate-500 shadow-panel">正在打开用户详情…</div>}>
      <UserDetailScreen />
    </Suspense>
  );
}
