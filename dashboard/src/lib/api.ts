import type {
  CreateDashboardUserInput,
  DashboardToolPayload,
  DashboardUserDetailResponse,
  DashboardUserSummary,
  SaveDashboardSnapshotInput,
  SaveDashboardToolInput,
  SaveDashboardUserProfileInput,
} from '@/lib/types';

function trimTrailingSlash(value: string) {
  return value.replace(/\/$/, '');
}

function getApiBaseUrl() {
  const explicitBase = process.env.NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_API_BASE_URL?.trim();
  if (explicitBase) {
    return trimTrailingSlash(explicitBase);
  }
  if (typeof window !== 'undefined' && window.location.origin) {
    return trimTrailingSlash(window.location.origin);
  }
  return 'http://127.0.0.1:8080';
}

async function requestJson<T>(path: string, init?: RequestInit): Promise<T> {
  const method = init?.method?.toUpperCase() ?? 'GET';
  const response = await fetch(`${getApiBaseUrl()}${path}`, {
    cache: method === 'GET' ? (init?.cache ?? 'no-store') : init?.cache,
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(init?.headers ?? {}),
    },
  });
  if (!response.ok) {
    let message = `请求失败：${response.status}`;
    try {
      const body = (await response.json()) as { message?: string };
      if (body.message) {
        message = body.message;
      }
    } catch {
      // 非 JSON 响应（如 HTML 错误页），使用默认消息
    }
    throw new Error(message);
  }
  return (await response.json()) as T;
}

export async function fetchDashboardUsers() {
  const response = await requestJson<{ success: true; users: DashboardUserSummary[] }>('/dashboard/users');
  return response.users;
}

export async function fetchDashboardUserDetail(userId: string) {
  return requestJson<DashboardUserDetailResponse>(`/dashboard/users/${encodeURIComponent(userId)}`);
}

export async function fetchDashboardTool(userId: string, toolId: string) {
  return requestJson<{ success: true; tool: DashboardToolPayload }>(
    `/dashboard/users/${encodeURIComponent(userId)}/tools/${encodeURIComponent(toolId)}`,
  );
}

export async function updateDashboardTool(input: SaveDashboardToolInput) {
  return requestJson<{ success: true; tool: DashboardToolPayload }>(
    `/dashboard/users/${encodeURIComponent(input.userId)}/tools/${encodeURIComponent(input.toolId)}`,
    {
      method: 'PUT',
      body: JSON.stringify({
        version: input.version,
        data: input.data,
        message: '由 dashboard 管理台保存',
      }),
    },
  );
}

export async function updateDashboardUserSnapshot(input: SaveDashboardSnapshotInput) {
  return requestJson<DashboardUserDetailResponse>(
    `/dashboard/users/${encodeURIComponent(input.userId)}/snapshot`,
    {
      method: 'PUT',
      body: JSON.stringify({
        tools_data: input.toolsData,
        message: '由 dashboard JSON 管理页保存',
      }),
    },
  );
}

export async function updateDashboardUserProfile(input: SaveDashboardUserProfileInput) {
  return requestJson<{ success: true; user: DashboardUserSummary }>(
    `/dashboard/users/${encodeURIComponent(input.userId)}`,
    {
      method: 'PATCH',
      body: JSON.stringify({
        display_name: input.displayName,
        notes: input.notes,
        is_enabled: input.isEnabled,
      }),
    },
  );
}

export async function createDashboardUser(input: CreateDashboardUserInput) {
  return requestJson<{ success: true; user: DashboardUserSummary }>('/dashboard/users', {
    method: 'POST',
    body: JSON.stringify({
      user_id: input.userId,
      display_name: input.displayName,
      notes: input.notes,
      is_enabled: input.isEnabled,
    }),
  });
}
