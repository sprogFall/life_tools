# sync_server（life_tools 同步后端）

这是 `life_tools` 的后端同步服务，基于 **Python + FastAPI**。  
客户端（Flutter）与服务端当前统一使用 `POST /sync/v2`；历史 `POST /sync`（v1）已移除。

它同时承担 Dashboard API：`dashboard/` 静态面板通过同一个服务读取用户、快照、工具数据和同步记录。

## 决策规则

同步 v2 以服务端 `server_revision` 为主决策依据，并保留 `updated_at` 作为同游标兜底：

- 服务端没有快照：客户端非空时 `use_client`，双方都空时 `noop`
- 服务端 revision 大于客户端 `last_server_revision` 且服务端非空：`use_server`
- 客户端空库且服务端非空：`use_server`，避免新装应用覆盖已有数据
- 服务端为空但客户端非空：`use_client`
- 双方 revision 未拉开时，比较全量快照里最大的 `updated_at` / `updated_at_ms`
- 双方都没有变化：`noop`
- 客户端可在用户确认覆盖方向后传 `force_decision=use_server|use_client`

## 同步记录（审计日志）

服务端会在发生实际同步变更时记录差异与结果（`use_client`/`use_server`），`noop` 不记录。

- 列表：`GET /sync/records?user_id=...&limit=50&before_id=...`
- 详情：`GET /sync/records/{id}?user_id=...`

## 历史快照与回退（防覆盖）

服务端会把每次“写入服务端”的全量快照按 `server_revision` 留存，支持：

- 查询某个版本快照：`GET /sync/snapshots/{revision}?user_id=...`
- 回退服务端到历史版本（会生成新的 `server_revision`，并记录一条 `decision=rollback` 的同步记录）：
  - `POST /sync/rollback`，body：`{"user_id":"...","target_revision":1}`

## Dashboard API

Dashboard 相关路由：

- 用户列表：`GET /dashboard/users`
- 创建用户：`POST /dashboard/users`
- 用户详情：`GET /dashboard/users/{user_id}`
- 更新用户资料：`PATCH /dashboard/users/{user_id}`
- 整体替换快照：`PUT /dashboard/users/{user_id}/snapshot`
- 查看单工具快照：`GET /dashboard/users/{user_id}/tools/{tool_id}`
- 更新单工具快照：`PUT /dashboard/users/{user_id}/tools/{tool_id}`

Dashboard 写入会生成 `decision=dashboard_update` 的同步记录，并在保存前执行工作记录相关规则，保证工时归属等数据结构能被客户端继续导入。

## 安全边界

- 服务默认没有内建强认证授权；公网部署必须放在可信网关、反向代理鉴权或内网环境后面。
- 默认允许 CORS `*`，适合自建/内网和静态 Dashboard 部署；公网多租户场景需要收紧。
- SQLite 数据文件未加密，服务器磁盘和备份需要自行保护。

## 本地开发

### 1) 创建虚拟环境并安装依赖

```bash
cd backend/sync_server
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
```

### 2) 启动服务

```bash
.venv/bin/uvicorn sync_server.main:app --reload --host 0.0.0.0 --port 8080
```

默认数据落盘到：`backend/sync_server/data/sync.db`  
也可以通过环境变量覆盖：

```bash
export SYNC_SERVER_DB_PATH="/tmp/life_tools_sync.db"
```

### 3) Flutter 客户端如何配置

同步设置页填写（建议）：
- `serverUrl`：`http://127.0.0.1`（或 `http://<局域网IP>`）
- `serverPort`：`8080`
- 其他（自定义 Header / 私网 WiFi 白名单）按需配置

说明：客户端若 `serverUrl` 不带 `http://`/`https://`：
- 公网地址默认补 `https://`
- 本地/内网默认补 `http://`
但仍建议你显式填写 scheme，避免误配导致 TLS 握手失败。

## Docker 部署（推荐）

在你的服务器上执行：

```bash
cd backend/sync_server
docker compose up -d --build
```

- 服务端默认监听：`0.0.0.0:8080`
- 数据文件默认持久化在：`backend/sync_server/data/sync.db`（通过 compose 挂载到容器 `/data/sync.db`）

## 运行测试

```bash
cd backend/sync_server
.venv/bin/pytest
```
