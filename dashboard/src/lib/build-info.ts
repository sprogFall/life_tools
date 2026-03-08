export interface DashboardBuildInfo {
  gitVersion: string;
  buildTime: string | null;
}

function normalizeBuildField(value: string | undefined): string | null {
  const normalized = value?.trim();
  return normalized ? normalized : null;
}

export function getDashboardBuildInfo(env: NodeJS.ProcessEnv = process.env): DashboardBuildInfo {
  return {
    gitVersion: normalizeBuildField(env.NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_GIT_VERSION) ?? 'unknown',
    buildTime: normalizeBuildField(env.NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_BUILD_TIME),
  };
}
