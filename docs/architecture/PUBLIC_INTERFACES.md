# life_tools 公共接口与调用链

更新时间：2026-03-11

这里的“公共接口”指会被多个页面、多个工具、或多个子系统复用的入口，不展开列出单个页面内部的私有方法。

## 1. Flutter 全局公共入口

这些对象由 `lib/main.dart` 注入，是当前应用壳层最核心的服务接口。

| 名称 | 类型 | 位置 | 作用 |
| --- | --- | --- | --- |
| `SettingsService` | `ChangeNotifier` | `lib/core/services/settings_service.dart` | 工具排序、隐藏、默认工具、主题模式等壳层设置 |
| `AiConfigService` | `ChangeNotifier` | `lib/core/ai/ai_config_service.dart` | AI 配置持久化 |
| `AiCallHistoryService` | `ChangeNotifier` | `lib/core/ai/ai_call_history_service.dart` | AI 调用记录持久化 |
| `ObjStoreConfigService` | `ChangeNotifier` | `lib/core/obj_store/obj_store_config_service.dart` | 对象存储配置与密钥管理 |
| `SyncConfigService` | `ChangeNotifier` | `lib/core/sync/services/sync_config_service.dart` | 同步配置管理 |
| `SyncLocalStateService` | `ChangeNotifier` | `lib/core/sync/services/sync_local_state_service.dart` | 记录本地数据绑定的同步用户 |
| `SyncService` | `ChangeNotifier` | `lib/core/sync/services/sync_service.dart` | 同步主入口 |
| `MessageService` | `ChangeNotifier` | `lib/core/messages/message_service.dart` | 消息中心与系统通知协同 |
| `ToastService` | `ChangeNotifier` | `lib/core/widgets/ios26_toast.dart` | 全局轻提示 |
| `WifiService` | Service | `lib/core/sync/services/wifi_service.dart` | 网络与 WiFi 信息读取 |
| `TagService` | `ChangeNotifier` | `lib/core/tags/tag_service.dart` | 公共标签体系维护 |
| `AiService` | Service | `lib/core/ai/ai_service.dart` | 统一 AI 调用入口 |
| `ObjStoreService` | Service | `lib/core/obj_store/obj_store_service.dart` | 上传、资源解析、本地缓存 |

## 2. 关键服务接口

### 2.1 `SyncService`

位置：`lib/core/sync/services/sync_service.dart`

核心职责：

- 校验同步配置
- 执行网络预检
- 导出工具快照与应用配置快照
- 调用同步后端
- 导入服务端返回的快照

当前主要入口：

- `sync({SyncTrigger trigger = SyncTrigger.manual, SyncForceDecision? forceDecision}) -> Future<bool>`
- `applyServerSnapshot(Map<String, Map<String, dynamic>> toolsData) -> Future<String?>`
- `getUserMismatch({SyncConfig? config}) -> SyncUserMismatch?`

重要依赖：

- `SyncApiClient`
- `ToolSnapshotExporter`
- `ToolRegistry`
- `BackupRestoreService`
- `SyncNetworkPrecheck`

### 2.2 `BackupRestoreService`

位置：`lib/core/sync/services/backup_restore_service.dart`

核心职责：

- 导出全部工具数据
- 导入备份数据
- 处理敏感配置是否导出
- 作为 `AppConfigSyncProvider` 的底层实现

这意味着“备份恢复”和“应用配置同步”已经共享部分实现，而不是两套平行逻辑。

### 2.3 `ObjStoreService`

位置：`lib/core/obj_store/obj_store_service.dart`

核心职责：

- 根据当前配置上传对象
- 解析对象的可访问 URI
- 管理磁盘缓存与内存缓存
- 对图片做上传前压缩

主要入口：

- `uploadBytes(...) -> Future<ObjStoreObject>`
- `resolveUri({required String key}) -> Future<String>`
- `getCachedFile({required String key}) -> Future<File?>`
- `ensureCachedFile(...) -> Future<File?>`

### 2.4 `AiService`

位置：`lib/core/ai/ai_service.dart`

核心职责：

- 统一封装 AI 文本对话调用
- 使用当前配置或显式配置调用 OpenAI 风格接口
- 写入 AI 调用历史

### 2.5 `MessageService`

位置：`lib/core/messages/message_service.dart`

核心职责：

- 写入与更新消息
- 未读/已读状态维护
- 清理过期消息
- 触发本地通知

## 3. 工具注册与同步接口

### 3.1 `ToolRegistry`

位置：`lib/core/registry/tool_registry.dart`

职责：

- 注册当前可见工具
- 持有工具元信息
- 挂接各工具的 `ToolSyncProvider`

当前注册结果：

| toolId | 名称 | syncProvider |
| --- | --- | --- |
| `work_log` | 工作记录 | `WorkLogSyncProvider` |
| `stockpile_assistant` | 囤货助手 | `StockpileSyncProvider` |
| `overcooked_kitchen` | 胡闹厨房 | `OvercookedSyncProvider` |
| `xiao_mi` | 小蜜 | 无 |
| `tag_manager` | 标签管理 | `TagSyncProvider` |

### 3.2 `ToolSyncProvider`

位置：`lib/core/sync/interfaces/tool_sync_provider.dart`

统一约定：

- `toolId`
- `exportData()`
- `importData(Map<String, dynamic> data)`

当前同步快照除了工具自身 provider 外，还包含：

- `AppConfigSyncProvider`

位置：`lib/core/sync/services/app_config_sync_provider.dart`

它负责把应用配置纳入同步快照，因此“公共配置接口”实际上也属于同步协议的一部分。

### 3.3 快照导出器

位置：`lib/core/sync/services/tool_snapshot_exporter.dart`

职责：

- 串行导出所有 provider 的快照
- 校验 `data` 字段
- 汇总失败工具

这保证了同步和备份不会悄悄产出一个不完整快照。

## 4. 同步后端接口

后端实现位置：`backend/sync_server/sync_server/main.py`

### 4.1 基础接口

- `GET /healthz`

### 4.2 同步接口

- `POST /sync`
  - 旧版兼容接口
- `POST /sync/v2`
  - 当前客户端使用的主接口

`/sync/v2` 的关键请求语义：

- `protocol_version`
- `user_id`
- `client_time`
- `client_state.last_server_revision`
- `client_state.client_is_empty`
- `tools_data`

关键响应语义：

- `decision`
  - `use_server`
  - `use_client`
  - `noop`
- `server_revision`
- `tools_data`

### 4.3 同步审计与回退接口

- `GET /sync/records`
- `GET /sync/records/{record_id}`
- `GET /sync/snapshots/{revision}`
- `POST /sync/rollback`

这些接口既支撑人工排查，也支撑 Dashboard 的快照查看与回退场景。

## 5. Dashboard API

Dashboard 相关接口同样在 `backend/sync_server/sync_server/main.py`。

### 5.1 用户级接口

- `GET /dashboard/users`
- `POST /dashboard/users`
- `GET /dashboard/users/{user_id}`
- `PATCH /dashboard/users/{user_id}`

### 5.2 快照与工具级接口

- `PUT /dashboard/users/{user_id}/snapshot`
- `GET /dashboard/users/{user_id}/tools/{tool_id}`
- `PUT /dashboard/users/{user_id}/tools/{tool_id}`

这些接口让 Dashboard 可以：

- 查看用户资料和快照摘要
- 编辑用户元信息
- 整体替换某个用户的快照
- 单独查看和修改某个工具的快照

## 6. Dashboard 前端接口使用面

Dashboard 工程位置：`dashboard/**`

当前前端通过 `dashboard/src/lib/api.ts`、`dashboard/src/lib/actions.ts` 与后端交互，主要消费两类路由：

- `/dashboard/*`
- `/sync/*`

因此从系统边界上看，Dashboard 不是单独的后端服务，而是复用同步后端提供的数据接口。

## 7. 关键调用链

### 7.1 启动自动同步

调用链：

`MyApp -> StartupWrapper -> SyncConfigService -> WifiService(可选) -> SyncService.sync(trigger: auto)`

特征：

- UI 构建后异步执行
- 私网模式下若未连接 WiFi 会静默跳过
- 成功或失败通过 Toast 提示

### 7.2 手动同步

调用链：

`同步页 -> SyncService -> SyncNetworkPrecheck -> ToolSnapshotExporter -> SyncApiClient -> ToolSyncProvider.importData`

### 7.3 备份恢复

调用链：

`BackupRestorePage -> BackupRestoreService -> ToolSyncProvider / 配置服务 -> ShareService / ReceiveShareService`

### 7.4 AI 调用

调用链：

`业务页 -> AiService -> OpenAiClient -> 外部 OpenAI 风格接口`

### 7.5 对象存储上传与缓存

调用链：

`业务页 -> ObjStoreService -> LocalObjStore / QiniuClient / DataCapsuleClient`

展示时：

`业务页 -> ObjStoreService.ensureCachedFile -> 内存缓存 / 磁盘缓存 / 远端下载`

## 8. 当前接口层面的注意点

- 客户端同步主路径已收敛到 `/sync/v2`
- 历史兼容仍保留在后端，不代表客户端仍走回退流程
- 小蜜当前未接入统一同步 provider
- Dashboard 改动的是后端快照数据，因此任何快照结构调整都必须同时考虑客户端导入兼容性
