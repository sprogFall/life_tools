'use client';

import { useEffect, useRef, useState } from 'react';

import { fetchDashboardUserDetail } from '@/lib/api';
import { getActionErrorMessage } from '@/lib/error-utils';
import type { DashboardUserDetailResponse } from '@/lib/types';

export function useUserDetail(userId: string) {
  const [detail, setDetail] = useState<DashboardUserDetailResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const latestRequestIdRef = useRef(0);

  const loadDetail = async (nextUserId: string) => {
    const requestId = latestRequestIdRef.current + 1;
    latestRequestIdRef.current = requestId;

    if (!nextUserId) {
      if (requestId === latestRequestIdRef.current) {
        setDetail(null);
        setError('缺少 userId，请先从同步用户目录进入。');
        setLoading(false);
      }
      return;
    }

    setLoading(true);
    try {
      const nextDetail = await fetchDashboardUserDetail(nextUserId);
      if (requestId !== latestRequestIdRef.current) {
        return;
      }
      setDetail(nextDetail);
      setError(null);
    } catch (loadError) {
      if (requestId !== latestRequestIdRef.current) {
        return;
      }
      setDetail(null);
      setError(getActionErrorMessage(loadError));
    } finally {
      if (requestId === latestRequestIdRef.current) {
        setLoading(false);
      }
    }
  };

  useEffect(() => {
    void loadDetail(userId);
  }, [userId]);

  return { detail, setDetail, loading, error, loadDetail };
}
