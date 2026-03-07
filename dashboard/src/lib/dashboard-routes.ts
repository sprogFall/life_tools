export function buildUserRouteHref(
  pathname: '/users/detail' | '/users/json',
  userId: string,
  toolId?: string | null,
) {
  return {
    pathname,
    query: toolId ? { userId, tool: toolId } : { userId },
  };
}
