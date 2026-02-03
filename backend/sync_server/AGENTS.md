<INSTRUCTIONS>
# sync_server（后端同步服务）开发规范

## 交流要求
- 永远使用中文回复

## 开发原则
1. **TDD**：新增/修改功能前先补测试（`backend/sync_server/tests/**`），并在交付前保证测试全绿
2. **简约原则**：优先实现最小可用、可维护的方案，避免过度设计
3. **零容忍重复**：抽取可复用函数/模块，禁止复制粘贴式逻辑
4. **安全默认值**：不在日志/异常中输出敏感信息（例如 Token、自定义 Header）

## 项目结构
- `backend/sync_server/sync_server/main.py`：FastAPI 应用与路由（`/sync`、`/sync/v2`）
- `backend/sync_server/sync_server/storage.py`：SQLite 快照存储（按 `user_id` 保存全量快照）
- `backend/sync_server/sync_server/sync_logic.py`：同步判定逻辑（按最新 `updated_at`）
- `backend/sync_server/tests/**`：pytest 测试

## 同步协议与前端（Flutter）对接地址声明
- Flutter 客户端配置项在：`lib/core/sync/models/sync_config.dart`
- 客户端会访问：`{serverUrl}:{serverPort}`（注意：未填写 scheme 时客户端会默认补 `https://`）
  - 本地开发建议在客户端 `serverUrl` 填：`http://127.0.0.1` 或 `http://<局域网IP>`，避免 https 解析/证书问题
- 请求路径：
  - 优先：`POST /sync/v2`
  - 回退：`POST /sync`

## 后端运行与校验
- 创建虚拟环境并安装依赖：
  - `python3 -m venv .venv`
  - `.venv/bin/pip install -r requirements-dev.txt`
- 运行测试：`.venv/bin/pytest`
- 启动服务：`.venv/bin/uvicorn sync_server.main:app --host 0.0.0.0 --port 8080`
</INSTRUCTIONS>

