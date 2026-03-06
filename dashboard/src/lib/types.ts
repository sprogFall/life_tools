export interface DashboardToolSummary {
  tool_id: string;
  version: number;
  total_items: number;
  section_counts: Record<string, number>;
}

export interface DashboardSnapshotSummary {
  has_snapshot: boolean;
  server_revision: number;
  updated_at_ms: number;
  tool_count: number;
  tool_ids: string[];
  total_item_count: number;
  tool_summaries: DashboardToolSummary[];
}

export interface DashboardUserSummary {
  user_id: string;
  display_name: string;
  notes: string;
  is_enabled: boolean;
  created_at_ms: number;
  updated_at_ms: number;
  last_seen_at_ms: number | null;
  snapshot: DashboardSnapshotSummary;
}

export interface DashboardSyncRecordSummary {
  id: number;
  user_id: string;
  protocol_version: number;
  decision: string;
  server_time: number;
  client_time: number | null;
  client_updated_at_ms: number;
  server_updated_at_ms_before: number;
  server_updated_at_ms_after: number;
  server_revision_before: number;
  server_revision_after: number;
  diff_summary: Record<string, unknown>;
}

export interface DashboardToolSnapshot {
  version: number;
  data: Record<string, unknown>;
}

export interface DashboardUserDetailResponse {
  success: boolean;
  user: DashboardUserSummary;
  snapshot: DashboardSnapshotSummary & {
    tools_data: Record<string, DashboardToolSnapshot>;
  };
  recent_records: DashboardSyncRecordSummary[];
}

export interface DashboardToolPayload {
  tool_id: string;
  version: number;
  data: Record<string, unknown>;
  summary: DashboardToolSummary;
}

export interface DashboardActionResult {
  success: boolean;
  message: string;
}

export interface SaveDashboardToolInput {
  userId: string;
  toolId: string;
  version: number;
  data: Record<string, unknown>;
}

export interface SaveDashboardUserProfileInput {
  userId: string;
  displayName: string;
  notes: string;
  isEnabled: boolean;
}

export interface CreateDashboardUserInput {
  userId: string;
  displayName: string;
  notes: string;
  isEnabled: boolean;
}
