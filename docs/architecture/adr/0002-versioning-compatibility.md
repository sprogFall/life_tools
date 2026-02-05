# ADR 0002：版本管理与兼容策略（快照 / 协议 / 存储 Key）

日期：2026-02-05  
状态：已接受（Accepted）

## 背景

该仓库包含多类“可演进的数据结构/接口”：

- SharedPreferences 中的配置与本地状态（AI/同步/对象存储等）
- SQLite Schema 迁移（业务表长期演进）
- 工具快照（备份/同步共用）
- 同步协议（v1→v2）

这些结构必须支持长期演进与兼容，否则会出现：

- 老备份无法导入
- 新客户端无法与旧服务端同步
- 配置字段变更导致解析失败/崩溃

## 决策

1. **SharedPreferences Key 使用显式版本后缀**（例如 `*_v1`）
2. **工具快照必须包含 `version` 字段**，并在 `importData()` 中显式兼容旧版本
3. **同步协议采用路径 + payload 双重版本化**：
   - 路径：`/sync`（v1）、`/sync/v2`（v2）
   - payload：`protocol_version: 2`
   - 客户端对 404/405 自动回退 v1
4. **备份 JSON 有全局版本号**：`BackupRestoreService.backupVersion`
5. **新增字段优先可选（向后兼容）**：读取时使用 `containsKey`/默认值；删除字段需保留迁移窗口

## 理由

- 版本后缀让“数据来源/格式”可被快速识别，避免 silent break
- 工具快照版本化把兼容责任收敛到工具自身，避免全局导入逻辑膨胀
- 同步协议双版本化降低“灰度升级”风险：服务端/客户端可独立升级
- 备份全局版本号便于做“全局不可兼容变更”的快速拒绝与提示

## 影响

- 每个工具的 `importData()` 需要维护兼容分支（但范围清晰）
- 当 Schema/快照发生不兼容变更时，需要同步更新：
  - 对应 `version` / `backupVersion` / `protocol_version`
  - `docs/architecture/PUBLIC_INTERFACES.md` 的接口说明
  - 必要的迁移/降级逻辑

## 开放问题（后续可改进）

- 后端 records/rollback 等接口尚未挂载显式版本前缀（可考虑 `/api/v1/...`）
- 若快照体积持续增大，可评估：
  - per-tool revision / hash 元信息
  - decision=merge（冲突处理）
  - 工具内增量导出（但需协议扩展）

