# 公共接口与调用链梳理（life_tools）

更新时间：2026-02-05

> 说明：这里的“公共接口”指 **跨模块/跨工具会复用** 的入口（Service/Repository/Client/Widget/HTTP API）。工具内部的私有 Widget/方法不在此逐个枚举。

## 1) Flutter 侧公共入口（Provider 注入）

注入位置：`lib/main.dart` 的 `MultiProvider`（应用启动即初始化/可被业务侧 `context.read/watch` 使用）

| 名称 | 类型 | 定义位置 | 核心职责 | 关键方法（入参 → 返回） | 典型异常/失败形态 |
|---|---|---|---|---|---|
| `AiConfigService` | `ChangeNotifier` | `lib/core/ai/ai_config_service.dart` | AI 配置本地持久化（BaseURL/API Key/模型等） | `init()`；`save(AiConfig)`；`clear()` | 配置解析失败时降级为 `null` |
| `AiService` | Service | `lib/core/ai/ai_service.dart` | OpenAI 兼容对话入口（业务侧统一调用） | `chat(messages, ...) → AiChatResult`；`chatText(prompt, ...) → String`；`chatTextWithConfig(config, ...) → String` | `AiNotConfiguredException`；`AiApiException`（非 2xx、响应缺字段） |
| `ObjStoreConfigService` | `ChangeNotifier` | `lib/core/obj_store/obj_store_config_service.dart` | 对象存储配置 + AK/SK 存取（通过 `SecretStore`） | `init()`；`save(config, secrets, ...)`；`clear()` | `FormatException`（缺少必需密钥且不允许缺失） |
| `ObjStoreService` | Service | `lib/core/obj_store/obj_store_service.dart` | 本地/七牛/数据胶囊：上传、URL 解析、缓存下载 | `uploadBytes(bytes, filename) → ObjStoreObject`；`resolveUri(key) → String`；`ensureCachedFile(key, ...) → File?` | `ObjStoreNotConfiguredException`；`ObjStoreConfigInvalidException`；`ObjStoreUploadException`；`ObjStoreQueryException` |
| `TagService` | `ChangeNotifier` | `lib/core/tags/tag_service.dart` | 公共标签查询/维护（跨工具复用） | `registerToolTagCategories(toolId, categories)`；`refreshAll()`；`refreshToolTags(toolId)`；`createTagForToolCategory(...) → int` | 参数非法通常抛 `ArgumentError`；写库失败会触发刷新兜底 |
| `MessageService` | `ChangeNotifier` | `lib/core/messages/message_service.dart` | 消息中心（去重、未读、过期清理、可选系统通知） | `upsertMessage(...) → int?`；`markMessageRead(id)`；`purgeExpired(now) → int`；`scheduleSystemNotification(...)` | 写库失败由 Repository 抛；通知失败平台侧会吞并 `debugPrint` |
| `SyncConfigService` | `ChangeNotifier` | `lib/core/sync/services/sync_config_service.dart` | 同步配置（serverUrl/port/userId/customHeaders 等） | `init()`；`save(SyncConfig)`；`updateLastSyncState(time, serverRevision)` | 配置解析失败时降级为 `null` |
| `SyncLocalStateService` | `ChangeNotifier` | `lib/core/sync/services/sync_local_state_service.dart` | 记录“本地数据绑定的 userId”，避免误覆盖 | `init()`；`setLocalUserId(userId)`；`clear()` | 无 |
| `SyncService` | `ChangeNotifier` | `lib/core/sync/services/sync_service.dart` | 同步主入口：预检→导出快照→调用 API→按决策导入 | `sync(trigger, forceDecision) → bool`；`applyServerSnapshot(toolsData) → String?` | `SyncApiException`（封装后给用户友好文案）；工具导入失败会记录并继续 |
| `SettingsService` | `ChangeNotifier` | `lib/core/services/settings_service.dart` | 工具排序/隐藏/默认工具等“壳层配置” | `updateHomeToolOrder(ids)`；`setDefaultTool(id)`；`setToolHidden(id, hidden)` | SQLite 写入失败会向上抛出 |
| `WifiService` | Provider | `lib/core/sync/services/wifi_service.dart` | 网络状态/SSID 读取（同步私网预检使用） | `getNetworkStatus() → NetworkStatus`；`getCurrentWifiName() → String?` | 读取 SSID 失败返回 `null` |
| `ToastService` | `ChangeNotifier` | `lib/core/widgets/ios26_toast.dart` | 全局轻提示（成功/失败/信息） | `showSuccess(text)`；`showError(text)` | 无 |

## 2) 跨工具公共接口（同步/备份统一协议）

### 2.1 `ToolSyncProvider`（工具快照接口）

定义：`lib/core/sync/interfaces/tool_sync_provider.dart`

- `toolId`：必须与 `ToolInfo.id` 一致
- `exportData()`：**全量导出**，建议返回结构：
  - `version`：工具快照版本号（int）
  - `data`：工具数据（Map）
- `importData(snapshot)`：按 `version` 做兼容处理，建议事务保证原子性

工具实现（部分）：

- `WorkLogSyncProvider`：`lib/tools/work_log/sync/work_log_sync_provider.dart`（`version: 1`）
- `StockpileSyncProvider`：`lib/tools/stockpile_assistant/sync/stockpile_sync_provider.dart`（`version: 2`，兼容 `1`）
- `OvercookedSyncProvider`：`lib/tools/overcooked_kitchen/sync/overcooked_sync_provider.dart`（`version: 3`，兼容 `1/2`）
- `TagSyncProvider`：`lib/core/tags/tag_sync_provider.dart`（`version: 1`）
- `AppConfigSyncProvider`：`lib/core/sync/services/app_config_sync_provider.dart`（`version: 1`，用于同步 app 配置快照，包含 `updated_at_ms`）

### 2.2 快照编排与导入顺序

- 快照导出编排：`ToolSnapshotExporter.exportAll(...)`（`lib/core/sync/services/tool_snapshot_exporter.dart`）
  - 要点：逐个 provider 导出；若失败会抛异常并取消本次同步/备份（避免不完整快照）
- 导入顺序：`sortToolEntries(...)`（`lib/core/sync/services/tool_sync_order.dart`）
  - 要点：`tag_manager` 优先导入，避免其它工具的标签关联丢失

## 3) 网络 API（同步后端）

客户端调用封装：`lib/core/sync/services/sync_api_client.dart`

后端实现：`backend/sync_server/sync_server/main.py`

### 3.1 同步接口（v1）

- `POST /sync`
  - 请求：`SyncRequestV1`（`backend/sync_server/sync_server/schemas.py`）
    - `user_id: string`
    - `force_decision?: "use_server" | "use_client"`
    - `tools_data: { [toolId]: snapshot }`
  - 响应：`SyncResponseV1`
    - `success: bool`
    - `server_time: int(ms)`
    - `tools_data?: { [toolId]: snapshot }`（当服务端决定回传覆盖）

### 3.2 同步接口（v2，推荐）

- `POST /sync/v2`
  - 请求：`SyncRequestV2`
    - `protocol_version: 2`
    - `user_id: string`
    - `client_time: int(ms)`
    - `client_state: { last_server_revision?: int, client_is_empty: bool }`
    - `force_decision?: "use_server" | "use_client"`
    - `tools_data: { [toolId]: snapshot }`
  - 响应：`SyncResponseV2`
    - `success: bool`
    - `decision: "use_server" | "use_client" | "noop"`
    - `server_time: int(ms)`
    - `server_revision: int`
    - `tools_data?: { [toolId]: snapshot }`（当 `decision=use_server`）

### 3.3 同步记录与回退（排障/运维能力）

- `GET /sync/records?user_id=...&limit=...&before_id=...`
- `GET /sync/records/{id}?user_id=...`
- `GET /sync/snapshots/{revision}?user_id=...`
- `POST /sync/rollback`：`{ user_id, target_revision }`

## 4) 公共 UI 组件接口（跨页面复用）

> 这些组件属于“设计系统/壳层复用”，属于公共接口的一部分（页面不应重复造轮子）。

| 组件 | 定义位置 | 作用 | 典型入参 |
|---|---|---|---|
| `IOS26Theme` | `lib/core/theme/ios26_theme.dart` | iOS 26 视觉规范：颜色/圆角/间距/文字样式 | 业务侧通过 `IOS26Theme.xxx` 访问常量与样式 |
| `IOS26AppBar` | `lib/core/ui/app_scaffold.dart` | 统一顶部栏（含 home 形态） | `title`、`showBackButton`、`home(onSettingsPressed)` |
| `AppScaffold` | `lib/core/ui/app_scaffold.dart` | 统一页面骨架与 SafeArea 策略 | `useSafeArea`、`body` |
| `IOS26ToastOverlay` + `ToastService` | `lib/core/widgets/ios26_toast.dart` | 全局 Toast | `showSuccess/showError` |
| `IOS26HomeLeadingButton` | `lib/core/widgets/ios26_home_leading_button.dart` | 工具页统一“返回首页”入口 | 无（按需配置最小点击尺寸） |

## 5) 关键调用链路（导航级视角）

### 5.1 启动 → 自动同步（异步）

- `MyApp` 构建 → `StartupWrapper.initState()` → `Future.microtask(_performStartupTasks)`
- 若 `SyncConfig.autoSyncOnStartup=true` 且配置合法：
  - 私网模式：若当前非 WiFi 则静默跳过
  - 调用 `SyncService.sync(trigger: auto)`

对应时序图：`docs/architecture/exports/svg/sequences/startup_auto_sync.svg`

### 5.2 手动同步（同步页）→ 后端（HTTP）→ 覆盖导入

- UI（同步设置页/同步记录页）→ `SyncService.sync(...)`
- `SyncNetworkPrecheck.check(...)`（公网/私网 SSID 白名单）
- `ToolSnapshotExporter.exportAll(...)`（导出各工具快照）
- `SyncApiClient.syncV2(...)`（优先）→ 失败 404/405 回退 `sync(...)`
- `decision=use_server`：`ToolSyncProvider.importData(...)`（按顺序导入）

对应时序图：`docs/architecture/exports/svg/sequences/sync_v2.svg`

### 5.3 AI 调用（OpenAI 兼容）

- UI（工具内 AI 功能）→ `AiService.chatText(...)`
- 读取配置：`AiConfigService.config`（必须合法）
- `OpenAiClient.chatCompletions(...)` → HTTP → OpenAI 兼容 API

对应时序图：`docs/architecture/exports/svg/sequences/ai_chat_text.svg`

### 5.4 对象存储上传/缓存

- UI 选择文件 → `ObjStoreService.uploadBytes(...)`
  - 本地存储：写入 `LocalObjStore`，返回 `file://...`
  - 七牛：`QiniuClient.uploadBytes` + URL 拼装（公有/私有）
  - 数据胶囊：`DataCapsuleClient.putObject` +（私有）预签名 GET URL
- 展示资源：优先 `ensureCachedFile(...)` 命中内存/磁盘缓存，未命中再下载并落盘

对应时序图：`docs/architecture/exports/svg/sequences/obj_store_upload_and_cache.svg`

### 5.5 备份/还原（分享接收）

- 导出：`BackupRestoreService.exportAsJson(includeSensitive)` → `ShareService.shareBackup(...)`
- 导入：`ReceiveShareService` 收到文件 → `BackupRestorePage` → `BackupRestoreService.restoreFromJson(...)`

对应时序图：`docs/architecture/exports/svg/sequences/backup_restore_share.svg`

## 6) 版本管理策略（已落地 + 建议）

### 6.1 已落地

- **存储 Key 版本后缀**：SharedPreferences key 多使用 `*_v1`（如 `sync_config_v1`、`ai_config_v1`）
- **工具快照 version**：各 `ToolSyncProvider.exportData()` 返回 `version`，`importData()` 支持多版本兼容
- **同步协议版本**：HTTP 路径 `v2`（`/sync/v2`）+ `protocol_version: 2`；客户端自动回退 v1
- **备份版本**：`BackupRestoreService.backupVersion = 1`

### 6.2 建议补齐（架构层面）

- **后端 API 显式版本前缀**：例如 `/api/v1/sync`（当前用路径区分 v1/v2，但 records/rollback 等仍是未版本化的）
- **接口兼容规则写入 ADR**：新增字段优先可选；废弃字段给出迁移窗口；变更以 `version/protocol_version` 为准

