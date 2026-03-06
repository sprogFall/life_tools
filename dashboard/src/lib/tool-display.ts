import { getToolConfig } from '@/lib/tool-config';

export function getToolDisplayText(toolId: string) {
  return getToolConfig(toolId).name;
}
