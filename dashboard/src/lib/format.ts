import clsx from 'clsx';

import type { DashboardUserSummary } from '@/lib/types';

export function cn(...values: Array<string | false | null | undefined>) {
  return clsx(values);
}

export function formatTimestamp(value: number | null | undefined) {
  if (!value) {
    return '—';
  }
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(value));
}

export function formatNumber(value: number) {
  return new Intl.NumberFormat('zh-CN').format(value);
}

export function getUserDisplayName(user: Pick<DashboardUserSummary, 'display_name' | 'user_id'>) {
  const name = user.display_name.trim();
  return name || user.user_id;
}

export function truncateJsonPreview(value: unknown) {
  const text = typeof value === 'string' ? value : JSON.stringify(value);
  if (!text) {
    return '—';
  }
  return text.length > 48 ? `${text.slice(0, 45)}...` : text;
}
