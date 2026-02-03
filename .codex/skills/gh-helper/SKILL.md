---
name: gh-helper
description: GitHub 仓库检索与项目剖析助手：用于从 GitHub 搜索参考实现（repos/code/issues），并对目标仓库生成结构化剖析报告（目录、依赖、CI、技术栈、元信息）。当你需要分析 GitHub 项目、对比候选仓库、快速定位入口/构建方式、或收集可复用实现时使用。
---

# gh-helper

## 你能用它做什么

- **找参考**：用 GitHub Search API 快速搜同类仓库/实现片段/Issue 与 PR。
- **剖析项目**：把一个仓库快速“结构化拆解”，产出可复用的 Markdown 报告，方便后续深挖与对比。

## 快速开始（最常用）

### 1) 在 GitHub 上找参考项目（repos/code/issues）

准备（可选但强烈建议）：

- 设置环境变量 `GITHUB_TOKEN`（避免限流、提高成功率；注意不要把 Token 打进日志/报告）。

示例：

```bash
# 找同类仓库（按 star 排序）
python3 scripts/gh_search.py repos -q 'flutter sqlite offline language:Dart stars:>200 pushed:>2024-01-01 archived:false' --sort stars --order desc --per-page 10

# 在代码里定点找实现（先锁定 repo 或 org 再查）
python3 scripts/gh_search.py code -q 'repo:flutter/flutter filename:pubspec.yaml cupertino_icons' --per-page 10

# 找 Issue/PR（适合找踩坑与迁移经验）
python3 scripts/gh_search.py issues -q 'org:flutter is:issue is:open "sqlite" label:bug' --per-page 10
```

更多 qualifiers 速查：阅读 `references/github-search-cheatsheet.md`。

### 2) 对目标仓库生成剖析报告（Markdown）

示例（远程仓库）：

```bash
python3 scripts/gh_repo_report.py -r octocat/Hello-World --api --out /tmp/repo_report.md
```

示例（本地仓库）：

```bash
python3 scripts/gh_repo_report.py -r . --out /tmp/repo_report.md
```

## 推荐工作流（从“找参考”到“深挖落地”）

### 场景 A：你还没有目标仓库（先找参考）

1. 用 `scripts/gh_search.py repos` 搜到 10~30 个候选
2. 按以下维度快速筛选（先粗后细）：
   - 活跃度：`pushed:`、是否 archived、最近 release/commit
   - 许可证：是否能商用/二开/闭源
   - 技术栈：语言/平台/依赖是否匹配你的约束
3. 对 3~5 个候选跑 `scripts/gh_repo_report.py --api` 生成报告
4. 做一张对比表（见下方“交付模板”），选出 1~2 个深入阅读

### 场景 B：你已经有目标仓库（直接剖析）

1. 跑 `scripts/gh_repo_report.py` 先得到“结构视图”（目录/依赖/CI/关键文件）
2. 结合你的目标锁定入口：
   - 先看 README 与 CI（如何 build/test/run）
   - 再找启动流程与核心模块（主入口、路由、DI/Provider 初始化等）
3. 深挖前先做“最小闭环”：
   - 能否在本地跑通 lint/test/build（不要一上来读全仓库）

### 场景 C：需要定位“某个实现怎么做”（以点带面）

1. 用 `scripts/gh_search.py code` 定点搜（优先限定 `repo:` / `org:` / `filename:` / `path:`）
2. 把找到的关键文件路径与片段整理成“参考实现清单”
3. 回到目标仓库，按同样入口/模块对照实现（差异点就是迁移/复用的风险点）

剖析清单（更系统）：阅读 `references/repo-analysis-checklist.md`。

## 交付模板（建议固定格式，复用结论）

### 1) 单仓库剖析报告（建议章节）

1. 基本信息：repo、commit、Stars/Forks、License、最近提交
2. TL;DR：一句话结论 + 3~5 条证据
3. 项目结构：目录、关键文件、CI/CD
4. 依赖概览：核心依赖、平台/插件依赖、可能的坑
5. 入口与关键链路：启动流程、核心模块、数据流
6. 风险点与建议：迁移/复用成本、替代方案

### 2) 多仓库对比表（建议字段）

- repo / stars / license / last push
- 技术栈匹配度（语言/平台/依赖）
- 复杂度（目录规模、模块拆分、是否 monorepo）
- 可复用性（架构清晰度、可扩展点、测试覆盖/CI）
- 风险（breaking 频率、平台坑点、权限/隐私/安全）
