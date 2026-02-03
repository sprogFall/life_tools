# sync_server（life_tools 同步后端）

这是 `life_tools` 的后端同步服务，基于 **Python + FastAPI**。  
客户端（Flutter）会优先请求 `POST /sync/v2`，若返回 404/405 才回退到 `POST /sync`（v1）。

## 决策规则（按“最新更新时间”）

- 以全量快照里出现的最大 `updated_at`（epoch ms）作为“快照最新更新时间”
- 若服务端快照更新：返回 `use_server`（v2）/ `tools_data`（v1）让客户端覆盖导入
- 若客户端快照更新：返回 `use_client`（v2）并在服务端覆盖保存
- 若双方相同：`noop`
- **空数据保护**：客户端空库不会覆盖服务端非空快照

## 同步记录（审计日志）

服务端会在发生实际同步变更时记录差异与结果（`use_client`/`use_server`），`noop` 不记录。

- 列表：`GET /sync/records?user_id=...&limit=50&before_id=...`
- 详情：`GET /sync/records/{id}?user_id=...`

## 历史快照与回退（防覆盖）

服务端会把每次“写入服务端”的全量快照按 `server_revision` 留存，支持：

- 查询某个版本快照：`GET /sync/snapshots/{revision}?user_id=...`
- 回退服务端到历史版本（会生成新的 `server_revision`，并记录一条 `decision=rollback` 的同步记录）：
  - `POST /sync/rollback`，body：`{"user_id":"...","target_revision":1}`

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
