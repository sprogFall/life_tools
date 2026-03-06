import type { DashboardToolPayload, DashboardUserDetailResponse, DashboardUserSummary } from '@/lib/types';

export function buildOverviewStats(users: DashboardUserSummary[]) {
  return {
    totalUsers: users.length,
    enabledUsers: users.filter((item) => item.is_enabled).length,
    activeUsers: users.filter((item) => item.snapshot.has_snapshot || item.last_seen_at_ms !== null).length,
    syncedTools: users.reduce((total, item) => total + item.snapshot.tool_count, 0),
    managedRecords: users.reduce((total, item) => total + item.snapshot.total_item_count, 0),
  };
}

export function resolveSelectedToolId(selected: string | null | undefined, toolIds: string[]) {
  if (selected && toolIds.includes(selected)) {
    return selected;
  }
  return toolIds[0] ?? null;
}

export function buildToolPayload(
  detail: DashboardUserDetailResponse,
  toolId: string,
): DashboardToolPayload | null {
  const snapshot = detail.snapshot.tools_data[toolId];
  if (!snapshot) {
    return null;
  }
  const summary =
    detail.snapshot.tool_summaries.find((item) => item.tool_id === toolId) ?? {
      tool_id: toolId,
      version: snapshot.version,
      total_items: 0,
      section_counts: {},
    };

  return {
    tool_id: toolId,
    version: snapshot.version,
    data: snapshot.data,
    summary,
  };
}
