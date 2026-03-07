import type { DashboardToolSnapshot } from '@/lib/types';

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function parseJsonValue(text: string) {
  try {
    return JSON.parse(text) as unknown;
  } catch (error) {
    throw new Error(compactJsonErrorMessage(error));
  }
}

function normalizeDashboardToolSnapshot(rawSnapshot: unknown, toolId: string): DashboardToolSnapshot {
  if (!isRecord(rawSnapshot)) {
    throw new Error(`工具 ${toolId} 的快照必须是对象`);
  }

  const version = Number(rawSnapshot.version);
  if (!Number.isFinite(version) || version <= 0) {
    throw new Error(`工具 ${toolId} 缺少合法 version`);
  }

  if (!isRecord(rawSnapshot.data)) {
    throw new Error(`工具 ${toolId} 的 data 必须是对象`);
  }

  return {
    version,
    data: rawSnapshot.data,
  };
}

export function formatJsonText(value: unknown) {
  return JSON.stringify(value, null, 2);
}

export function compactJsonErrorMessage(error: unknown, prefix = 'JSON 解析失败') {
  const rawMessage = error instanceof Error ? error.message : String(error ?? '未知错误');
  const singleLine = rawMessage.replace(/\s+/g, ' ').trim();
  return `${prefix}：${singleLine}`;
}

export function parseDashboardToolsDataJson(text: string) {
  const parsed = parseJsonValue(text);

  if (!isRecord(parsed)) {
    throw new Error('JSON 根节点必须是对象');
  }

  const normalized: Record<string, DashboardToolSnapshot> = {};
  for (const [toolId, rawSnapshot] of Object.entries(parsed)) {
    normalized[toolId] = normalizeDashboardToolSnapshot(rawSnapshot, toolId);
  }

  return normalized;
}

export function parseDashboardToolSnapshotJson(text: string, toolId: string) {
  return normalizeDashboardToolSnapshot(parseJsonValue(text), toolId);
}
