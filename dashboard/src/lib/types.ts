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

export interface SaveDashboardSnapshotInput {
  userId: string;
  toolsData: Record<string, DashboardToolSnapshot>;
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

// 外拍助手模板相关类型
export interface WorkPhotoTemplate {
  id: number | null;
  name: string;
  sort_index: number;
  is_archived: number;
  created_at: number;
  updated_at: number;
}

export interface WorkPhotoHierarchyLevel {
  id: number | null;
  template_id: number | null;
  parent_level_id: number | null;
  name: string;
  sort_index: number;
  is_required: number;
  is_archived: number;
  created_at: number;
  updated_at: number;
}

export interface WorkPhotoHierarchyOption {
  id: number | null;
  level_id: number;
  parent_option_id: number | null;
  name: string;
  sort_index: number;
  is_archived: number;
  created_at: number;
  updated_at: number;
}

export interface WorkPhotoCaptureItem {
  id: number | null;
  template_id: number | null;
  parent_level_id: number | null;
  name: string;
  sort_index: number;
  min_count: number;
  max_count: number | null;
  is_archived: number;
  created_at: number;
  updated_at: number;
}

export interface WorkPhotoTemplateData {
  templates: WorkPhotoTemplate[];
  hierarchy_levels: WorkPhotoHierarchyLevel[];
  hierarchy_options: WorkPhotoHierarchyOption[];
  capture_items: WorkPhotoCaptureItem[];
}

export interface WorkPhotoToolData {
  version: number;
  data: WorkPhotoTemplateData;
}
