# life_tools APP 架构总览

更新时间：2026-04-21

范围：

- Flutter 客户端：`lib/**`
- 同步后端：`backend/sync_server/**`
- Dashboard：`dashboard/**`

## 1. 一句话结论

`life_tools` 是一个以 Flutter 为主客户端、以 SQLite 为默认本地数据源、以 Provider 为壳层依赖注入方式的多工具箱应用。AI、对象存储、自建同步和 Dashboard 都围绕这套本地优先模型按需接入，而不是反过来主导业务结构。

## 2. 当前顶层结构

| 目录 | 角色 | 说明 |
| --- | --- | --- |
| `lib/main.dart` | 启动入口 | 初始化数据库运行环境、核心服务、提醒检查、分享接收与全局 Provider |
| `lib/core/**` | 共享基础设施 | AI、同步、对象存储、消息、通知、数据库、标签、主题、通用 UI |
| `lib/pages/**` | 全局页面 | 首页、设置页、工具管理、关于页等壳层页面 |
| `lib/tools/**` | 业务工具模块 | 工作记录、囤货助手、胡闹厨房、小蜜等功能模块 |
| `test/**` | 测试 | Flutter 侧单元、组件和页面测试 |
| `backend/sync_server/**` | 后端服务 | 同步协议、快照存储、同步记录、回退、Dashboard 数据接口 |
| `dashboard/**` | 管理面板 | Next.js 静态站点，用于查看和编辑后端快照数据 |

## 3. 运行时分层

推荐用下面这个方向理解依赖关系：

`Widget / Page -> Service / ChangeNotifier -> Repository / Client -> SQLite / File / HTTP`

### 3.1 UI 层

主要目录：

- `lib/pages/**`
- `lib/tools/**/pages/**`
- `lib/core/ui/**`
- `lib/core/widgets/**`

职责：

- 渲染页面和组件
- 接收用户输入
- 通过 Provider 读取服务状态
- 调用服务层方法触发行为

约束：

- 不直接处理 SQL、文件路径拼接或 HTTP 细节
- 不在 Widget 内堆积跨模块业务规则

### 3.2 服务层

主要形态：

- `ChangeNotifier` 服务：例如 `SettingsService`、`SyncService`、`MessageService`
- 普通服务：例如 `AiService`、`ObjStoreService`

职责：

- 承接 UI 行为
- 编排多仓储、多配置、多外部能力
- 提供跨工具可复用的稳定入口

典型例子：

- `SyncService`：同步预检、快照导出、调用后端、导入服务端数据
- `BackupRestoreService`：统一导出/导入工具数据与配置
- `ObjStoreService`：对象上传、资源地址解析、文件缓存
- `MessageService`：消息去重、持久化、过期清理、系统通知分发

### 3.3 数据访问层

主要形态：

- `*Repository`
- `DatabaseHelper`
- `DatabaseSchema`
- `LocalObjStore`

职责：

- 对 SQLite、SharedPreferences、本地文件进行读写封装
- 处理导入导出时的数据映射
- 保持对上层的稳定接口

### 3.4 外部集成层

主要形态：

- `OpenAiClient`
- `SyncApiClient`
- `QiniuClient`
- `DataCapsuleClient`
- FastAPI 后端

职责：

- 管理 HTTP 请求和响应
- 承接外部服务差异
- 把错误归一为可处理的异常或响应结构

## 4. Flutter 启动流程

真实入口见 `lib/main.dart`。

### 4.1 初始化顺序

应用启动时依次完成：

1. `WidgetsFlutterBinding.ensureInitialized()`
2. Android 尝试请求高刷新率
3. 桌面端初始化 `sqflite_common_ffi`
4. `ToolRegistry.instance.registerAll()`
5. 初始化设置、AI 配置、AI 调用历史、对象存储配置
6. 初始化同步配置与本地同步状态
7. 创建 `SyncService`
8. 初始化本地通知和 `MessageService`
9. 启动囤货助手与胡闹厨房的提醒检查
10. 构建 `MyApp` 并注入全局 Provider

### 4.2 全局 Provider 结构

当前 `MultiProvider` 注入的核心对象包括：

- `SettingsService`
- `AiConfigService`
- `AiCallHistoryService`
- `ObjStoreConfigService`
- `SyncConfigService`
- `SyncLocalStateService`
- `SyncService`
- `MessageService`
- `ToastService`
- `WifiService`
- `TagService`
- `AiService`
- `ObjStoreService`

这说明项目的壳层不是以单一状态树驱动，而是以一组相互独立、职责明确的服务对象为中心。

### 4.3 启动后任务

`StartupWrapper` 在 UI 构建后异步执行一次性任务，当前主要是：

- 按配置决定是否启动自动同步
- 私网同步模式下先检查 WiFi
- 自动同步成功或失败时通过 `ToastService` 提示

同时，应用恢复到前台时会：

- 再次尝试请求高刷新率
- 清理过期消息
- 按天触发囤货助手和胡闹厨房提醒检查

## 5. 工具模块架构

`ToolRegistry` 当前注册了 5 个工具：

| toolId | 名称 | 页面入口 | 是否接入同步 |
| --- | --- | --- | --- |
| `work_log` | 工作记录 | `WorkLogToolPage` | 是 |
| `stockpile_assistant` | 囤货助手 | `StockpileToolPage` | 是 |
| `overcooked_kitchen` | 胡闹厨房 | `OvercookedToolPage` | 是 |
| `xiao_mi` | 小蜜 | `XiaoMiToolPage` | 否 |
| `tag_manager` | 标签管理 | `TagManagerToolPage` | 是 |

### 5.1 当前模块模式

支持同步的工具通常包含：

- `pages/`
- `repository/`
- `services/`
- `models/`
- `sync/`

并通过 `ToolInfo.syncProvider` 接入统一快照体系。

### 5.2 共享而非复制

工具不会重复实现下面这些基础能力：

- 标签体系
- 消息中心
- 备份恢复
- 对象存储
- AI 配置与调用入口
- 同步协议接入

这也是当前代码结构最重要的架构约束之一。

## 6. 同步与备份架构

### 6.1 同步快照模型

所有支持同步的工具都通过 `ToolSyncProvider` 导出自己的快照：

- `toolId`
- `exportData()`
- `importData(Map<String, dynamic>)`

`SyncService` 在工具快照之外，还会额外注入 `AppConfigSyncProvider`，把应用配置纳入统一同步数据。

这意味着当前“同步的数据范围”已经不只是业务工具，还包括一部分壳层配置。

### 6.2 导出与导入编排

- 导出：`ToolSnapshotExporter.exportAll(...)`
- 导入顺序：`tool_sync_order.dart`
- 备份恢复统一入口：`BackupRestoreService`

其中标签管理优先导入，目的是避免其它工具在导入时找不到标签引用。

### 6.3 当前同步协议现状

当前客户端 `SyncService` 与后端都已统一收敛到 `/sync/v2`；历史 `/sync`（v1）兼容路由已下线。

当前同步关键步骤：

1. 校验同步配置
2. 检查本地用户与目标同步用户是否匹配
3. 执行网络预检
4. 导出全部工具快照与应用配置快照
5. 调用 `/sync/v2`
6. 根据服务端 `decision` 决定是否导入服务端数据
7. 更新本地 `lastSyncTime`、`serverRevision` 和 `localUserId`

### 6.4 本地用户保护

`SyncLocalStateService` 记录“当前本地数据绑定到哪个 userId”，在自动同步和手动同步时用于阻止错误覆盖。这是目前比“账号登录”更关键的保护机制。

## 7. AI、对象存储与消息中心

### 7.1 AI

当前 AI 架构由三部分组成：

- `AiConfigService`：配置持久化
- `AiService`：统一调用入口
- `OpenAiClient`：外部接口适配

AI 能力是可选的，未配置时不影响核心本地功能。

### 7.2 对象存储

`ObjStoreService` 支持三类后端：

- 本地对象存储
- 七牛云
- 数据胶囊

当前对象存储架构有两个重点：

- 上传前按类型尝试压缩图片
- 展示时优先读取内存缓存和磁盘缓存，减少重复下载

### 7.3 消息中心

`MessageService` 连接：

- SQLite 消息仓储
- 过期清理
- 去重更新
- 移动端本地通知

这使得“提醒”不再分散在各工具内部，而是统一落到消息中心。

## 8. 后端与 Dashboard 架构

### 8.1 sync_server 的双重角色

`backend/sync_server` 当前不仅是同步后端，还承担 Dashboard 数据接口。

它提供两类路由：

- 同步相关：`/sync/v2`、`/sync/records`、`/sync/snapshots/{revision}`、`/sync/rollback`
- Dashboard 相关：`/dashboard/users`、`/dashboard/users/{user_id}`、`/dashboard/users/{user_id}/snapshot`、`/dashboard/users/{user_id}/tools/{tool_id}`

### 8.2 Dashboard 的定位

`dashboard/` 是一个 Next.js 静态面板，主要用途是：

- 浏览用户与快照摘要
- 查看工具级快照数据
- 对指定用户或指定工具进行编辑

它不是移动端/桌面端 Flutter 页面的一部分，而是独立部署的管理入口。

## 9. 当前架构优点

- 本地优先模型清晰，工具离线可用
- 新增工具的接入方式比较统一
- 跨工具能力没有散落在各业务模块里重复实现
- 同步、备份、Dashboard 共享同一套快照心智模型
- 后端实现足够轻，适合自建或本地部署

## 10. 当前架构风险与后续建议

### 10.1 明确存在的风险

- 同步后端默认未内建强认证授权，公网部署需要自行补齐
- SQLite 默认未加密，本机安全依赖设备环境
- 工具同步仍是全量快照模式，数据量继续增长后会推高同步和导入成本
- Dashboard 直接编辑快照数据时，需要持续保持与客户端导入逻辑兼容

### 10.2 建议优先级

建议优先关注：

1. 同步后端的认证、限流、审计
2. 大快照导入时的性能和失败恢复
3. Dashboard 修改快照后的兼容校验
4. 架构图与 `main.dart` 注入结构的持续同步
