export default function Loading() {
  return (
    <div className="space-y-6">
      <div className="h-40 animate-pulse rounded-4xl bg-slate-100" />
      <div className="grid gap-4 lg:grid-cols-4">
        <div className="h-28 animate-pulse rounded-4xl bg-slate-100" />
        <div className="h-28 animate-pulse rounded-4xl bg-slate-100" />
        <div className="h-28 animate-pulse rounded-4xl bg-slate-100" />
        <div className="h-28 animate-pulse rounded-4xl bg-slate-100" />
      </div>
      <div className="h-[420px] animate-pulse rounded-4xl bg-slate-100" />
    </div>
  );
}
