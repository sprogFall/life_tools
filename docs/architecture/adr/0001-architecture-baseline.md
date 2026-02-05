# ADR 0001：life_tools 架构基线（本地优先 + 可选联网）

日期：2026-02-05  
状态：已接受（Accepted）

## 背景

life_tools 的产品形态是“把生活拆成工具箱”：打开即首页卡片，进入即聚焦单工具。基线需求包括：

- 多端可用（Android/iOS/Web/Desktop）
- 离线可用，核心数据不依赖云账号
- 允许接入可选的联网能力（AI、对象存储、数据同步）
- 需要可维护、可迭代的模块边界（工具之间尽量隔离，公共能力统一入口）

## 决策

1. **客户端采用 Flutter + Dart 实现多端统一**
2. **数据默认本地落地 SQLite（sqflite）**，通过版本化 Schema 迁移（`DatabaseSchema.version`）
3. **全局状态与依赖注入采用 Provider + ChangeNotifier**
4. **跨工具公共能力在 `lib/core/**` 提供“公共入口”**，并在 `lib/main.dart` 统一注入：
   - AI：`AiService` / `AiConfigService`
   - 对象存储：`ObjStoreService` / `ObjStoreConfigService`
   - 同步：`SyncService` / `SyncConfigService` / `SyncLocalStateService`
   - 标签：`TagService`
   - 消息中心：`MessageService`（可选本地通知）
5. **同步采用“全量快照”模型，并支持协议版本演进（v2 优先、v1 回退）**
6. **备份/还原与同步共享同一套快照接口 `ToolSyncProvider`**，避免重复定义数据结构

## 理由

- Flutter 满足多端一致性与交付效率；
- SQLite 满足离线与可迁移；Schema 版本化保证长期演进；
- Provider + ChangeNotifier 在“工具箱类应用”的状态复杂度下足够轻量；
- 把可选联网能力做成显式配置与可注入服务，保证“不配置也能完整使用”；
- 用快照同步换取实现简单与可解释性；通过 v2 解决“空数据保护/决策依据不足”等问题。

## 影响（正/负）

### 正向

- 核心体验离线可用，迁移成本低（备份 JSON / 自建同步）
- 工具模块可按 Feature 拆分，公共能力入口统一
- 同步/备份共用快照接口，减少重复与不一致

### 代价/限制

- 快照同步对大数据量场景的 CPU/IO/网络更敏感，需要关注性能与分批/增量方案的可行性
- 不引入账号体系意味着服务端鉴权需自行补齐（当前默认实现未内置）

## 备选方案（未采用）

- Redux/BLoC 等更重的全局状态框架：对当前规模过重，且会引入额外样板代码
- Drift/Isar 等更高层的数据层：可带来类型安全/性能优势，但迁移成本与复杂度更高
- 增量同步（per-tool/per-record diff）：复杂度显著提升，先以快照满足当前规则与交付

