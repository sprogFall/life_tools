# Dashboard & 后端代码审查优化报告

**审查范围**: 最近 3 次提交（4590764 → 1eac86d → 168ef32）新增的 dashboard 前端 + 后端 API 代码
**审查日期**: 2026-03-07

---

## 修复清单

### 严重问题

| # | 文件 | 问题 | 修复方式 |
|---|------|------|----------|
| 1 | `dashboard/src/lib/api.ts` | `requestJson()` 先调用 `response.json()` 再检查 `response.ok`，当后端返回非 JSON 响应（如 HTML 错误页、502 网关错误）时直接崩溃 | 调整为先检查 `response.ok`，再解析 JSON；错误分支用 try-catch 包裹 JSON 解析 |
| 2 | `backend/.../main.py` | dashboard API 的 `update_dashboard_snapshot` 和 `update_dashboard_tool` 使用 `assert` 校验写入后的数据完整性，Python `-O` 模式下 assert 会被跳过，导致生产环境可能返回 None 结果 | 替换为 `if ... is None: raise HTTPException(500, ...)` |

### 中等问题

| # | 文件 | 问题 | 修复方式 |
|---|------|------|----------|
| 3 | `dashboard/src/lib/actions.ts` + `error-utils.ts` | 两个文件各有一份几乎相同的错误消息提取函数（`getErrorMessage` vs `getActionErrorMessage`），违反 DRY 原则 | 删除 actions.ts 中的重复函数，统一使用 error-utils.ts 导出的 `getActionErrorMessage` |
| 4 | `user-detail-screen.tsx` + `user-json-screen.tsx` | 两个页面组件包含完全相同的 `loadDetail()` 函数和 useEffect 逻辑（约 30 行重复） | 提取为自定义 hook `useUserDetail(userId)` 放在 `lib/use-user-detail.ts`，两个组件改为调用该 hook |
| 5 | `dashboard/src/lib/tool-relations.ts` | `asRows()` 中 `filter(Boolean) as Record<...>[]` 使用不安全的类型断言绕过 TypeScript 检查 | 改为类型守卫 `filter((x): x is Record<string, unknown> => x !== null)` |
| 6 | `dashboard/src/lib/tool-relations.ts` | `buildRelationContext()` 构建 tagOptions 时未检查重复，相同 tag_id 会反复追加产生重复选项 | 新增 `seenCategoryTags`/`seenToolTags` Set 在添加前去重 |
| 7 | `tool-workspace.tsx` `fromInputValue()` | JSON 类型字段直接调用 `JSON.parse(value)` 无错误处理，虽然调用处有 try-catch，但函数本身不安全 | 加 try-catch 并抛出带字段名的友好错误信息 |

### 低优先级优化

| # | 文件 | 问题 | 修复方式 |
|---|------|------|----------|
| 8 | `tool-workspace.tsx` 搜索过滤 | 使用 `JSON.stringify(item)` 做全文匹配，大数据量下性能差且搜索结果过于宽泛 | 改为 `Object.values(item).some(v => String(v).toLowerCase().includes(keyword))` |
| 9 | `tool-workspace.tsx` 列表渲染 | 列表 key 使用 `${sectionKey}-${index}`（数组索引），过滤后索引与原数组不匹配，可能导致 React 状态错乱 | 优先使用 `item.id` 作为 key，无 id 时降级为索引 |
| 10 | `user-profile-editor.tsx` | useEffect 依赖项列出了 `user.display_name, user.is_enabled, user.notes, user.user_id` 四个字段，如果 user 对象引用变了但某个字段巧合未变，effect 不会触发 | 简化依赖为 `[user]` |
| 11 | `dashboard/src/lib/format.ts` | `truncateJsonPreview()` 中 `JSON.stringify(value)` 未捕获异常，循环引用等特殊值会导致崩溃 | 加 try-catch，异常时返回占位符 `'—'` |

---

## 验证结果

- **前端测试**: 5 个测试文件、9 个用例全部通过
- **后端测试**: 23 个用例全部通过
- **TypeScript 编译**: 无错误、无警告

## 影响范围

- `dashboard/src/lib/api.ts` — 请求层核心修复
- `dashboard/src/lib/actions.ts` — 去重重构
- `dashboard/src/lib/error-utils.ts` — 无变更（被复用）
- `dashboard/src/lib/format.ts` — 安全加固
- `dashboard/src/lib/tool-relations.ts` — 类型安全 + 去重
- `dashboard/src/lib/use-user-detail.ts` — 新增共享 hook
- `dashboard/src/components/tool-workspace.tsx` — 搜索/key/解析 修复
- `dashboard/src/components/user-detail-screen.tsx` — 重构使用共享 hook
- `dashboard/src/components/user-json-screen.tsx` — 重构使用共享 hook
- `dashboard/src/components/user-profile-editor.tsx` — 依赖修正
- `backend/sync_server/sync_server/main.py` — assert 替换为异常
