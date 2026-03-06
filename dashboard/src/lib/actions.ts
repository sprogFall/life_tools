'use server';

import { revalidatePath } from 'next/cache';

import { createDashboardUser, updateDashboardTool, updateDashboardUserProfile } from '@/lib/api';
import type {
  CreateDashboardUserInput,
  DashboardActionResult,
  SaveDashboardToolInput,
  SaveDashboardUserProfileInput,
} from '@/lib/types';

function getErrorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }
  return '请求失败，请检查后端服务是否可用。';
}

export async function saveDashboardToolAction(
  input: SaveDashboardToolInput,
): Promise<DashboardActionResult> {
  try {
    await updateDashboardTool(input);
    revalidatePath('/');
    revalidatePath('/users');
    revalidatePath(`/users/${input.userId}`);
    return { success: true, message: '已保存到后端。' };
  } catch (error) {
    return { success: false, message: getErrorMessage(error) };
  }
}

export async function saveDashboardUserProfileAction(
  input: SaveDashboardUserProfileInput,
): Promise<DashboardActionResult> {
  try {
    await updateDashboardUserProfile(input);
    revalidatePath('/');
    revalidatePath('/users');
    revalidatePath(`/users/${input.userId}`);
    return { success: true, message: '用户信息已更新。' };
  } catch (error) {
    return { success: false, message: getErrorMessage(error) };
  }
}

export async function createDashboardUserAction(
  input: CreateDashboardUserInput,
): Promise<DashboardActionResult> {
  try {
    await createDashboardUser(input);
    revalidatePath('/');
    revalidatePath('/users');
    return { success: true, message: '同步用户已创建。' };
  } catch (error) {
    return { success: false, message: getErrorMessage(error) };
  }
}
