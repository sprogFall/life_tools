import { Suspense } from 'react';

import { UserJsonScreen } from '@/components/user-json-screen';

export default function UserJsonPage() {
  return (
    <Suspense fallback={<div className="rounded-4xl border border-slate-200 bg-white/85 px-6 py-16 text-center text-sm text-slate-500 shadow-panel">正在打开 JSON 管理页…</div>}>
      <UserJsonScreen />
    </Suspense>
  );
}
