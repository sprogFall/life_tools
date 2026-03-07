export function getActionErrorMessage(error: unknown) {
  if (error instanceof Error && error.message.trim()) {
    return error.message;
  }
  return '请求失败，请检查后端服务是否可用。';
}
