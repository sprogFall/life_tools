# life_tools 架构文档（可维护版）

> 目标：把当前仓库（Flutter App + 可选同步后端）的模块边界、公共接口、关键调用顺序、安全/性能要点用「可渲染、可导出、可迭代」的方式固化下来。

## 你会得到什么

- **主架构图（组件/分层）**：见 `docs/architecture/exports/svg/app_architecture.svg`
- **公共接口图（核心服务/接口关系）**：见 `docs/architecture/exports/svg/public_interfaces.svg`
- **状态管理与数据流图**：见 `docs/architecture/exports/svg/state_data_flow.svg`
- **关键时序图**（同步、AI、对象存储、备份/还原）：见 `docs/architecture/exports/svg/sequences/*.svg`
- **系统性分析文档**：`docs/architecture/APP_ARCHITECTURE.md`
- **公共接口梳理**：`docs/architecture/PUBLIC_INTERFACES.md`
- **ADR（架构决策记录）**：`docs/architecture/adr/README.md`

## 一键导出 PNG / SVG / PDF

```bash
bash scripts/render_architecture_diagrams.sh
```

> 可在仓库任意当前目录执行（脚本会自动切到仓库根目录）。

导出目录：

- PNG：`docs/architecture/exports/png/`
- SVG：`docs/architecture/exports/svg/`
- PDF：`docs/architecture/exports/pdf/`

### 渲染依赖

- 必需：`java`（用于运行 PlantUML）
- 必需：`curl`（首次/升级时下载 PlantUML jar）
- 推荐：`fonts-noto-cjk`（提供中文字体，避免导出图片/PDF 出现“方框”）
- 推荐：`graphviz`（提供 `dot`，提升组件/类图布局稳定性）
- 推荐：`librsvg2-bin`（提供 `rsvg-convert`，用于把 SVG 转 PDF；脚本优先走 png→pdf，未安装 PIL 时会尝试该方式）
- 推荐：`python3-pil`（脚本优先用 PNG 打包 PDF，保证跨机器打开不缺字；代价是 PDF 文本不可选择）

> 说明：PlantUML 由脚本从官方 GitHub Releases 自动下载（`latest`），并会自动替换历史旧版 jar（如 8059）。

> 说明：即使没有 `dot`，部分图（尤其是序列图）仍可正常导出；但「组件图/类图」在某些环境下可能布局变差或失败。

## 颜色编码规范（与图例一致）

| 颜色 | 层/类型 | 用途 |
|---|---|---|
| 蓝色系 | UI 层 | 页面/组件（Widgets） |
| 靛色系 | 状态管理 | Provider / ChangeNotifier 注入与监听 |
| 紫色系 | 业务服务层 | Service（AI/同步/消息/标签/对象存储…） |
| 绿色系 | 数据访问层 | Repository / SQLite / 本地文件 |
| 橙色系 | 网络/集成 | HTTP Client / 外部 API / 后端服务 |
| 灰色系 | 平台插件 | Notifications / Connectivity / File / Voice 等插件 |
| 红色系 | 安全控制点 | 认证/边界校验/敏感信息控制 |
| 黄色系 | 性能优化点 | 缓存/懒加载/压缩/去重等 |

## 更新维护指南（建议流程）

1. **新增/调整模块边界**：先更新 `docs/architecture/diagrams/app_architecture.puml`
2. **新增公共接口/协议变更**：同步更新：
   - `docs/architecture/PUBLIC_INTERFACES.md`
   - `docs/architecture/diagrams/public_interfaces.puml`
3. **新增关键流程**：在 `docs/architecture/diagrams/sequences/` 增加对应 `*.puml`
4. **补 ADR**：在 `docs/architecture/adr/` 新增 `00xx-*.md`
5. **重新导出**：运行 `bash scripts/render_architecture_diagrams.sh`
