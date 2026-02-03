# GitHub 项目剖析清单（Checklist）

> 目标：用一套固定框架快速建立“我理解这个项目了”的把握感，并能产出可复用的结论。

## 1) 明确目标与边界（先问清楚）

- 你要做什么：复用代码 / 迁移方案 / 二开 / 学习架构 / 排错 / 安全审计 / 性能优化？
- 约束是什么：语言/平台/许可证/时间/依赖限制/离线可用/企业内网等？
- 交付物是什么：技术选型对比、架构图、模块划分、迁移计划、风险清单、PoC？

## 2) 仓库健康度（适合先用 GitHub API/页面）

- Stars/Forks/Watchers、最近更新时间（`pushed_at`）
- 是否归档（archived）、是否活跃维护（最近 commit/PR）
- Issue/PR 处理速度（是否堆积）
- License 是否明确、是否符合你的使用场景（商用/闭源/分发）
- 是否有安全说明（`SECURITY.md`）、是否有贡献指南（`CONTRIBUTING.md`）

## 3) 构建与运行（最小闭环）

- README 是否给出完整的 build/test/run 步骤
- CI（GitHub Actions 等）里跑了哪些 job：lint/test/build/release？
- 常见入口：
  - Node：`package.json` 的 `scripts`
  - Python：`pyproject.toml` / `requirements.txt`、`pytest.ini`
  - Rust：`Cargo.toml`、`cargo test`
  - Go：`go.mod`、`go test ./...`
  - Flutter：`pubspec.yaml`、`flutter test` / `flutter analyze`

## 4) 代码结构与架构（从“目录 → 模块 → 依赖方向”下手）

- 顶层目录用途：`src/`、`lib/`、`packages/`、`apps/`、`examples/`、`docs/`
- 是否分层：UI / domain / data / infra（或 controller/service/repo 等）
- 依赖方向是否清晰：核心模块是否被业务层反向依赖？
- 关键入口文件：`main.*`、`app.*`、路由/启动流程、DI/Provider 初始化

## 5) 依赖与扩展点（最容易踩坑）

- 直接依赖 vs. 间接依赖（是否锁版本/是否经常 breaking）
- 平台相关依赖（iOS/Android/Linux/Windows/Web）
- 插件/扩展机制：hook、middleware、provider、plugin API、事件总线等

## 6) 安全与隐私（快速排雷）

- 是否存在硬编码密钥/Token/私钥（尤其是示例代码与 CI 配置）
- 网络请求是否默认 HTTPS；是否有证书校验/超时/重试策略
- 数据落盘位置与加密策略（本地数据库、缓存、日志）

## 7) 产出方式（建议固定模板）

- TL;DR：一句话结论 + 关键证据（例如：CI、依赖、目录结构）
- 架构图：用文字版模块图也可以（核心模块、依赖箭头）
- 迁移/复用建议：需要改哪些点、风险是什么、替代方案是什么
- 参考实现对比：列 3 个候选仓库，做表格（活跃度、License、架构、复杂度）

