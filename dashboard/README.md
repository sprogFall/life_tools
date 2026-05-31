# Dashboard 静态部署

`dashboard/` 是 `life_tools` 的独立管理面板，基于 Next.js 静态导出。它不直接保存数据，而是通过 `backend/sync_server` 暴露的 `/dashboard/*` 与 `/sync/*` API 读取和更新后端快照。

## 当前能力

- 用户管理：查看用户列表、创建用户、编辑展示名/备注/启用状态。
- 快照总览：查看用户当前 `server_revision`、更新时间、工具摘要和最近同步记录。
- 工具数据编辑：结构化编辑工作记录、囤货助手、胡闹厨房、标签管理和 `app_config`。
- 敏感字段保护：AI Key、对象存储密钥、自定义 Header 等字段在前端按配置掩码展示。
- JSON 管理：可查看和替换完整用户快照，也可编辑单个工具快照。
- 工作记录分析：工时树、归属画布、按标签/状态筛选、悬浮详情和工时柱状图。
- 同步排障：查看同步记录、差异摘要和历史快照；回退能力由后端 `/sync/rollback` 提供。
- 部署核对：构建产物写入 `dashboard-version.json` 并在侧边栏展示 Git 版本与构建时间。

## 构建

```bash
cd dashboard
npm install
npm run build
```

构建完成后会生成 `dashboard/dist`，可直接作为静态目录部署到 nginx。

构建产物会自动写入版本信息：

- 左侧边栏底部展示当前前端 `Git` 版本与构建时间
- 静态文件 `dashboard/dist/dashboard-version.json` 可直接用于部署后核对版本

## 后端连接

默认前端会请求当前站点同源下的后端接口：

- `/dashboard/*`
- `/sync/*`

推荐由 nginx 反向代理到 `backend/sync_server`。

Dashboard 写入的是服务端快照数据。修改快照结构、工具字段或 `app_config` 时，需要同步确认客户端 `ToolSyncProvider.importData()` 和 `AppConfigSyncProvider.importData()` 的兼容性。

如需在构建时指定独立后端地址，可设置：

```bash
NEXT_PUBLIC_LIFE_TOOLS_DASHBOARD_API_BASE_URL=https://your-api.example.com npm run build
```

## nginx 示例

```nginx
server {
  listen 80;
  server_name your-domain.example.com;

  root /var/www/life-tools-dashboard/dist;
  index index.html;

  location / {
    try_files $uri $uri.html $uri/ /index.html;
  }

  location /dashboard/ {
    proxy_pass http://127.0.0.1:8080/dashboard/;
  }

  location /sync/ {
    proxy_pass http://127.0.0.1:8080/sync/;
  }
}
```
