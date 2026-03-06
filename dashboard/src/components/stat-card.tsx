import { formatNumber } from '@/lib/format';

interface StatCardProps {
  label: string;
  value: number;
  hint: string;
}

export function StatCard({ label, value, hint }: StatCardProps) {
  return (
    <article className="rounded-4xl border border-slate-200/80 bg-white/80 p-5 shadow-panel backdrop-blur">
      <p className="text-sm font-medium text-slate-500">{label}</p>
      <p className="mt-3 font-mono text-3xl font-semibold text-ink">{formatNumber(value)}</p>
      <p className="mt-2 text-sm text-slate-600">{hint}</p>
    </article>
  );
}
