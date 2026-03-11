# life_tools 架构文档

更新时间：2026-03-11

这组文档用于说明当前仓库的真实架构边界，而不是抽象设计稿。范围覆盖：

- Flutter 主应用：`lib/**`
- 同步后端：`backend/sync_server/**`
- Dashboard：`dashboard/**`
- 架构图与关键时序图：`docs/architecture/diagrams/**`

## 先看什么

如果你第一次进入这个仓库，建议按下面顺序阅读：

1. [APP_ARCHITECTURE.md](APP_ARCHITECTURE.md)
2. [PUBLIC_INTERFACES.md](PUBLIC_INTERFACES.md)
3. `docs/architecture/exports/svg/*.svg`
4. [adr/README.md](adr/README.md)

## 文档地图

| 文档 | 作用 | 适合什么时候看 |
| --- | --- | --- |
| [APP_ARCHITECTURE.md](APP_ARCHITECTURE.md) | 系统级架构总览，说明模块边界、依赖方向、启动流程和关键数据流 | 想快速理解项目整体结构时 |
| [PUBLIC_INTERFACES.md](PUBLIC_INTERFACES.md) | 汇总 Flutter 公共服务、同步接口、Dashboard API 与关键调用链 | 想接入功能、改接口或排查调用链时 |
| [adr/README.md](adr/README.md) | 架构决策记录目录 | 想看历史约束和兼容策略时 |
| `exports/svg/app_architecture.svg` | 主架构图 | 想先看结构图再读代码时 |
| `exports/svg/public_interfaces.svg` | 公共接口图 | 想快速定位服务之间的关系时 |
| `exports/svg/state_data_flow.svg` | 状态与数据流图 | 想理解 Provider、Repository 和存储流向时 |
| `exports/svg/sequences/*.svg` | 关键时序图 | 想看启动同步、AI 调用、备份恢复等关键流程时 |

## 当前架构关注点

本项目现在的重点不是“做一个统一超级模块”，而是把多个工具模块放在同一个壳层里，复用一套共享基础设施：

- 本地优先：核心业务数据默认存 SQLite，本地可独立工作
- 工具注册：通过 `ToolRegistry` 统一注册页面、描述和同步适配器
- 共享服务：AI、对象存储、消息中心、同步、标签、设置都以公共服务形式注入
- 可选联网：AI、同步后端、对象存储、Dashboard 都是可选能力
- 多端运行：Flutter 客户端同时兼顾移动端、桌面端与 Web

## 当前文档与代码的对齐范围

以下内容已按当前代码校正：

- `lib/main.dart` 中的真实 Provider 注入结构
- `ToolRegistry` 中实际注册的工具集合
- `SyncService` 当前只走 `v2` 同步接口的实现
- `AppConfigSyncProvider` 已纳入统一同步快照
- `backend/sync_server` 同时承担同步后端和 Dashboard API
- `dashboard/` 为 Next.js 静态管理面板，不是 Flutter 内嵌管理页

## 一键导出图

```bash
bash scripts/render_architecture_diagrams.sh
```

导出目录：

- PNG：`docs/architecture/exports/png/`
- SVG：`docs/architecture/exports/svg/`
- PDF：`docs/architecture/exports/pdf/`

## 渲染依赖

- 必需：`java`
- 必需：`curl`
- 推荐：`fonts-noto-cjk`
- 推荐：`graphviz`
- 推荐：`librsvg2-bin`
- 推荐：`python3-pil`

## 建议维护方式

每次涉及以下改动时，应同步更新架构文档：

- `lib/main.dart` 的 Provider / 启动流程变化
- 新增或删除工具模块
- `ToolSyncProvider` 快照结构或导入顺序变化
- `backend/sync_server/sync_server/main.py` 路由变化
- `dashboard/src/**` 的 API 使用方式变化
- 架构图或时序图新增/失效

最小更新顺序：

1. 修改对应 `*.md`
2. 如有流程变化，修改 `diagrams/*.puml`
3. 重新导出图
4. 回写外层 `README.md` 的架构说明
