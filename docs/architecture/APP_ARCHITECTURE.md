# life_tools APP 架构系统性分析（基于仓库现状）

更新时间：2026-02-05  
范围：Flutter 客户端（`lib/**`）+ 可选同步后端（`backend/sync_server/**`）

## 0. 一句话总览

life_tools 是一个 **本地优先（SQLite）** 的多工具箱 Flutter 应用，通过 **Provider + ChangeNotifier** 做全局状态与依赖注入；AI、对象存储与数据同步均为 **可选联网能力**，其中同步采用 **“全量快照 + 协议版本（v2 优先、v1 回退）”** 的策略，并提供后端 FastAPI 参考实现。

对应主架构图：`docs/architecture/exports/svg/app_architecture.svg`

## 1. 模块层级结构（职责与边界）

### 1.1 顶层目录视角（功能边界）

- `lib/main.dart`：应用入口；初始化核心服务；`MultiProvider` 注入公共入口（AI/对象存储/标签/消息/同步等）。
- `lib/core/**`：跨工具公共能力（AI、同步、备份、消息、通知、对象存储、数据库、主题、UI 组件、语音输入等）。
- `lib/pages/**`：全局页面（首页、工具管理、AI/对象存储设置等）。
- `lib/tools/**`：各工具的 Feature 模块（页面 + 仓储 + 服务 + 同步适配器）。
- `backend/sync_server/**`：可选同步服务端（FastAPI + SQLite），提供 `/sync`、`/sync/v2` 等接口。

### 1.2 分层视角（依赖方向）

依赖方向（推荐理解）：**UI → Service（含状态）→ Repository → Storage/Network**

| 层 | 对应目录/文件 | 核心职责 | 边界/约束 |
|---|---|---|---|
| UI 层 | `lib/pages/**`、`lib/tools/**/pages/**`、`lib/core/ui/**`、`lib/core/widgets/**` | 交互/展示、路由导航、收集用户输入 | 不直接拼装 SQL/HTTP；通过 Service/Repository 访问数据 |
| 状态管理 & DI | `provider` + `ChangeNotifier`（见 `lib/main.dart`） | 全局依赖注入、状态监听、UI 重建 | 避免把重逻辑写进 Widget；把可测试逻辑下沉到 Service/Repository |
| 业务服务层（核心能力） | `lib/core/**` 中的 `*Service` | 封装业务规则、跨模块编排（同步/备份/对象存储缓存等） | 对外提供稳定“公共入口”；内部依赖 Repository/Client |
| 数据访问层 | `*Repository` + `DatabaseHelper/Schema` | SQLite CRUD、数据结构迁移、导入导出 | 只处理数据读写/映射；不持有 UI 状态 |
| 网络/集成层 | `*Client`（HTTP/签名） | 调用外部 API/后端；签名；超时与错误归一 | 不做 UI 提示；抛出结构化异常由上层处理 |
| 平台/插件层 | `flutter_local_notifications`、`connectivity_plus` 等 | 与系统能力对接（通知、网络、文件、语音等） | 通过 Service 包装，避免散落在业务代码 |

### 1.3 工具模块模式（`lib/tools/**`）

每个工具基本遵循“Feature 模块”结构：

- `pages/`：该工具 UI
- `repository/`：该工具 SQLite 数据访问
- `services/`：该工具业务编排（例如提醒、AI 辅助）
- `sync/`：实现 `ToolSyncProvider`，把工具数据适配到“备份/同步”的统一快照结构

工具注册由 `lib/core/registry/tool_registry.dart` 统一管理（创建 Repository/SyncProvider 并注册到 `ToolInfo`）。

## 2. 技术架构标注（技术栈 + 选型依据）

### 2.1 客户端（Flutter）

- 语言/框架：Flutter + Dart（多端统一）
- 状态管理：Provider（`MultiProvider` 注入）+ ChangeNotifier（服务状态可被 UI 监听）
  - 依据：仓库主要是“少量全局状态 + 多个工具页局部状态”，Provider 足够且实现成本低。
- 数据库：SQLite（`sqflite` + `sqflite_common_ffi`）
  - 依据：本地优先、离线可用；桌面端通过 FFI 支持。
- 配置存储：SharedPreferences（同步/AI/对象存储配置、本地同步用户态等）
- 网络：`http`（OpenAI 兼容、同步服务端、对象存储探测/下载等）
- 通知：`flutter_local_notifications` + `timezone`
- 文件/分享：`file_picker`、`image_picker`、`share_plus`、`receive_sharing_intent`
- 语音：`speech_to_text` + `record`（系统识别优先，录音用于降级方案/未来转写）

### 2.2 后端（可选同步服务端）

- 框架：FastAPI + Pydantic + Uvicorn
- 存储：SQLite（`sync.db`）
- 协议：HTTP JSON；实现 `/sync`（v1）与 `/sync/v2`（v2）并记录同步记录/回退

## 3. 数据流与状态管理（Provider/ChangeNotifier）

### 3.1 全局注入点（真实代码）

`lib/main.dart` 中 `MultiProvider` 注入的核心对象包括：

- 配置/状态：`SettingsService`、`AiConfigService`、`ObjStoreConfigService`、`SyncConfigService`、`SyncLocalStateService`
- 核心能力：`SyncService`、`MessageService`、`TagService`
- 调用入口：`AiService`、`ObjStoreService`
- 其它：`ToastService`、`WifiService`

### 3.2 数据流向（典型路径）

1. UI 读取状态：`context.watch<Service>()` / `Consumer` 监听 `ChangeNotifier`
2. UI 触发行为：`context.read<Service>().method(...)`
3. Service 编排：校验参数/配置 → 调用 Repository/Client
4. 数据写入：SQLite / SharedPreferences / 文件系统 / HTTP
5. 状态回推：Service `notifyListeners()` → Provider 通知 → Widget 重建

对应数据流图：`docs/architecture/exports/svg/state_data_flow.svg`

## 4. 同步/备份（本地快照统一接口）

### 4.1 统一快照接口

所有支持备份/同步的工具通过 `ToolSyncProvider` 统一导入/导出：

- `exportData(): Future<Map<String, dynamic>>`：返回 `{version, data, ...}` 的快照
- `importData(Map snapshot)`：按版本与字段兼容策略覆盖导入

工具导入顺序通过 `tool_sync_order.dart` 保证：`tag_manager` 优先导入，避免其它工具的标签引用丢失。

### 4.2 同步协议（v2 优先，v1 回退）

客户端 `SyncService.sync()`：

1. 预检：配置合法性、用户不匹配保护、网络条件（公网/私网 WiFi 白名单）
2. 收集全量工具快照（`ToolSnapshotExporter.exportAll`）
3. 优先调用 `/sync/v2`（包含 `last_server_revision` + `client_is_empty`），若 404/405 则回退 `/sync`
4. 根据服务端 decision：
   - `use_server`：覆盖导入 `tools_data`
   - `use_client`：服务端保存客户端快照并返回新 revision
   - `noop`：双方不变

后端在 `backend/sync_server/sync_server/main.py` 落地该协议，并额外提供同步记录查询与回退接口。

## 5. 安全与隐私设计（控制点与已知缺口）

### 5.1 已落地的安全控制点（代码可定位）

- **同步私网保护**：`SyncNetworkPrecheck` 强制 WiFi + SSID 白名单（避免在错误网络误同步）
- **用户不匹配保护**：`SyncLocalStateService` 记录本地数据绑定的 userId，自动同步遇到不匹配会阻断
- **对象存储路径安全**：`ObjStoreService` 本地文件读取使用 `path.isWithin` 防止 `../` 穿越
- **敏感信息导出控制**：`BackupRestoreService.exportConfigAsMap(includeSensitive)` 支持显式开关；未包含时会移除 `apiKey/customHeaders`
- **密钥最小暴露（避免明文）**：`PrefsSecretStore` 对对象存储 AK/SK 进行“避免明文落盘”的轻量处理（非硬件级安全）

### 5.2 需要在架构上明确的风险点

- 同步服务端默认实现未内置认证授权（依赖客户端 `customHeaders`，但服务端未校验）：若部署到公网需补齐鉴权/限流/审计。
- 本地 SQLite 未做加密：威胁模型若包含“本机失窃/越狱”，需评估数据库加密或系统安全存储。
- `PrefsSecretStore` 仅为“避免明文”，不等同 Keychain/Keystore；更强需求应替换为安全存储插件。

## 6. 性能设计（优化点与瓶颈）

### 6.1 已有优化点

- **对象存储缓存**：`ObjStoreService` 维护内存缓存 + 磁盘缓存（key 归一化 + sha1 文件名）
- **图片压缩**：上传前对常见图片格式做压缩（移动端），降低上传带宽与存储成本
- **减少无效写库**：`MessageService.upsertMessage` 对 dedupeKey 做“内容未变则不写库/不推送”
- **启动任务延迟**：`StartupWrapper` 自动同步延迟 1 秒，减少与启动期竞争资源

### 6.2 主要性能瓶颈（需在时序图中关注）

- **全量快照导出**：同步/备份每次导出所有工具数据（数据量大时 CPU/IO 压力显著）
- **网络超时**：AI、同步、对象存储下载均依赖网络；弱网会拉长关键路径
- **导入覆盖**：大批量写库导入时（特别是带事务的覆盖导入）可能造成 UI 卡顿，需要确保在异步/隔离上下文处理

## 7. 关键图与文档索引

- 主架构图：`docs/architecture/exports/svg/app_architecture.svg`
- 公共接口图：`docs/architecture/exports/svg/public_interfaces.svg`
- 状态/数据流：`docs/architecture/exports/svg/state_data_flow.svg`
- 同步时序：`docs/architecture/exports/svg/sequences/sync_v2.svg`
- 启动自动同步时序：`docs/architecture/exports/svg/sequences/startup_auto_sync.svg`
- AI 调用时序：`docs/architecture/exports/svg/sequences/ai_chat_text.svg`
- 对象存储上传/缓存时序：`docs/architecture/exports/svg/sequences/obj_store_upload_and_cache.svg`
- 备份/还原/分享时序：`docs/architecture/exports/svg/sequences/backup_restore_share.svg`
- 数据加载示例（WorkLog）：`docs/architecture/exports/svg/sequences/work_log_load_tasks.svg`

## 8. 现状说明（避免“画出来但代码不存在”）

- 仓库现状 **未发现传统意义的“登录/支付”业务链路**。同步的 userId 来自客户端配置（`SyncConfig.userId`），不等同账号体系。
- 联网能力均为可选项：未配置时核心工具仍可离线完整使用（本地 SQLite）。
