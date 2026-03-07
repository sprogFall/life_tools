# Dashboard 静态部署

## 构建

```bash
cd dashboard
npm install
npm run build
```

构建完成后会生成 `dashboard/dist`，可直接作为静态目录部署到 nginx。

## 后端连接

默认前端会请求当前站点同源下的后端接口：

- `/dashboard/*`
- `/sync/*`

推荐由 nginx 反向代理到 `backend/sync_server`。

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
