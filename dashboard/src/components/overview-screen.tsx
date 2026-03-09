'use client';

import { useEffect, useState } from 'react';

import { OverviewPage } from '@/components/overview-page';
import { DASHBOARD_PILL_BUTTON_MD } from '@/lib/button-styles';
import { fetchDashboardUsers } from '@/lib/api';
import { getActionErrorMessage } from '@/lib/error-utils';
import type { DashboardUserSummary } from '@/lib/types';

export function OverviewScreen() {
  const [users, setUsers] = useState<DashboardUserSummary[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const loadUsers = async () => {
    setLoading(true);
    try {
      const nextUsers = await fetchDashboardUsers();
      setUsers(nextUsers);
      setError(null);
    } catch (loadError) {
      setError(getActionErrorMessage(loadError));
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    void loadUsers();
  }, []);

  if (loading) {
    return (
      <div className="rounded-4xl border border-slate-200 bg-white/85 px-6 py-16 text-center text-sm text-slate-500 shadow-panel">
        正在加载管理台概览…
      </div>
    );
  }

  if (error) {
    return (
      <div className="rounded-4xl border border-rose-100 bg-rose-50/70 px-6 py-16 text-center shadow-panel">
        <p className="text-sm text-rose-600">{error}</p>
        <button
          type="button"
          onClick={() => void loadUsers()}
          className={`mt-4 ${DASHBOARD_PILL_BUTTON_MD} bg-ink text-white hover:bg-slate-800`}
        >
          重新加载
        </button>
      </div>
    );
  }

  return <OverviewPage users={users} />;
}
