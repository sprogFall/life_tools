# 数据同步协议（v2）设计说明

## 背景与现状评估

当前客户端同步实现（`lib/core/sync/services/sync_service.dart`）是“全量快照 + 服务端可选回传覆盖”模式：

- 客户端每次同步都会导出所有支持同步的工具数据（`ToolSyncProvider.exportData()`），并 POST 到 `/sync`
- 服务端若返回 `tools_data`，客户端就执行覆盖导入（`ToolSyncProvider.importData()`）

这套实现与“备份/还原”（`lib/core/sync/services/backup_restore_service.dart`）已经共用同一套底层数据结构（`ToolSyncProvider`），但存在关键不足：

- **缺少决策依据**：客户端没有“上次看到的服务端版本/游标”，服务端无法可靠判断“该用谁的数据”
- **缺少空数据保护**：新设备/空库首次同步时，可能把服务端已有数据误覆盖为“空快照”
- **缺少协议版本**：未来扩展字段会很难兼容

你提出的目标规则：

> 客户端发起同步时，如果服务端数据更新一点，或客户端无数据，就使用服务端的数据；否则让服务端更新成客户端送过去的数据。

v2 协议就是为此规则提供**明确、可扩展、可兼容**的出入参与决策流程。

## 设计目标

- **快照级别的“谁为准”**：本次同步要么以服务端快照为准（客户端覆盖导入），要么以客户端快照为准（服务端覆盖保存）
- **基于服务端游标（revision）**判断“服务端是否更新过”
- **客户端空数据保护**：客户端明确告知“本地是否为空”，避免误覆盖
- **与备份/还原共用数据结构**：`tools_data` 仍直接复用 `ToolSyncProvider.exportData()` 的输出
- **兼容旧服务端**：若服务端未实现 v2（HTTP 404/405），客户端自动回退到 v1 `/sync`

## 服务端数据模型建议

以“用户维度的全量快照”为最小实现：

- `user_id`：字符串
- `server_revision`：整数，服务端每次接受“use_client”覆盖保存时自增（或生成递增游标）
- `updated_at_ms`：更新时间（用于审计/排障，不作为决策核心）
- `tools_data_json`：JSON（对应 `tools_data` 全量快照）

未来可扩展为“按 toolId 分表/分列 + per-tool revision”，但 v2 先实现全量快照即可满足你的规则。

## 接口定义

### POST `/sync/v2`

#### 请求（SyncRequestV2）

```json
{
  "protocol_version": 2,
  "user_id": "u1",
  "client_time": 1730000000000,
  "client_state": {
    "last_server_revision": 7,
    "client_is_empty": false
  },
  "tools_data": {
    "work_log": { "version": 1, "data": { "tasks": [], "time_entries": [] } },
    "tag_manager": { "version": 1, "data": { "tags": [], "tool_tags": [] } }
  }
}
```

字段说明：

- `protocol_version`：固定为 `2`
- `user_id`：用户标识（现阶段由客户端配置，后续可迁移为 token/claims）
- `client_time`：客户端时间戳（毫秒），用于排障
- `client_state.last_server_revision`：客户端上次成功同步后记录的服务端游标；首次同步可为 `null`
- `client_state.client_is_empty`：客户端是否“本地无数据”（全量快照判空），用于空数据保护
- `tools_data`：工具全量快照，直接复用 `ToolSyncProvider.exportData()` 的输出

#### 响应（SyncResponseV2）

```json
{
  "success": true,
  "decision": "use_server",
  "message": "server newer than client",
  "server_time": 1730000000123,
  "server_revision": 9,
  "tools_data": {
    "work_log": { "version": 1, "data": { "tasks": [ { "id": 1 } ] } }
  }
}
```

字段说明：

- `success`：是否成功
- `decision`：
  - `use_server`：本次以服务端为准，客户端需覆盖导入 `tools_data`
  - `use_client`：本次以客户端为准，服务端需覆盖保存请求里的 `tools_data`
  - `noop`：双方均无需变更（可用于“双方都为空/双方相同”）
- `server_time`：服务端时间戳（毫秒）
- `server_revision`：服务端当前游标（客户端需要持久化）
- `tools_data`：仅当 `decision=use_server`（或未来 merge 模式）时返回

## 服务端决策逻辑（满足你的规则）

下面逻辑以“用户维度全量快照 + 单游标”为最小可行实现：

1. 读取服务端记录：`server_revision` 与 `server_tools_data`
2. 读取客户端 `last_server_revision`（空则按 0）
3. **若服务端游标 > 客户端游标**：`decision=use_server`，返回服务端快照
4. 否则（服务端不比客户端新）：
   - **若 `client_is_empty=true` 且服务端快照非空**：`decision=use_server`（空数据保护）
   - 否则：`decision=use_client`，服务端用客户端 `tools_data` 覆盖保存，`server_revision++`

注意：这等价于一种“乐观并发 + last-write-wins”的策略：任何时候只要服务端被别的客户端更新过（游标变大），本客户端就会在下次同步直接拉取并覆盖本地。

## 客户端实现要点（已在项目中落地）

- 同步入口仍为 `SyncService.sync()`
- 优先调用 `/sync/v2`，若返回 404/405 自动回退 `/sync`
- v2 下客户端会计算 `client_is_empty`（基于 `tools_data[*].data` 的深度判空）
- 收到 `decision=use_server` 时才覆盖导入 `tools_data`
- 每次 v2 成功都会写入：
  - `lastSyncTime = server_time`
  - `lastServerRevision = server_revision`

## 未来扩展方向（建议）

如果后续要支持“多端同时修改/更少覆盖”，可以在不破坏 v2 的前提下扩展：

- `tools_meta`：每个工具的 hash/size/updated_at
- `decision=merge`：服务端返回冲突信息或按工具维度决策
- per-tool revision：`server_revision_by_tool`，实现“某个工具更新一点”时仅回传该工具数据

