import type { DashboardToolSnapshot } from '@/lib/types';

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
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
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch (error) {
    throw new Error(compactJsonErrorMessage(error));
  }

  if (!isRecord(parsed)) {
    throw new Error('JSON 根节点必须是对象');
  }

  const normalized: Record<string, DashboardToolSnapshot> = {};
  for (const [toolId, rawSnapshot] of Object.entries(parsed)) {
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

    normalized[toolId] = {
      version,
      data: rawSnapshot.data,
    };
  }

  return normalized;
}
