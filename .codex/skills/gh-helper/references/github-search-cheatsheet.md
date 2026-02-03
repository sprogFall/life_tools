# GitHub 搜索速查（Qualifiers）

> 目标：把“找参考项目/参考实现”的检索成本降到最低。把下面的 qualifiers 直接拼到查询里即可。

## 仓库（Repositories）

- `language:Dart` / `language:TypeScript`：限定语言
- `stars:>1000` / `stars:100..500`：Star 范围
- `forks:>100`：Fork 范围
- `pushed:>2024-01-01`：最近更新（推送）时间
- `created:>2020-01-01`：创建时间
- `topic:cli` / `topic:ai`：话题
- `archived:false`：排除归档仓库
- `is:public` / `is:private`：公开/私有（需权限）
- `in:name` / `in:description` / `in:readme`：限定匹配范围
- `org:xxx` / `user:xxx`：限定组织/用户

示例：
- `flutter offline first language:Dart stars:>200 pushed:>2024-01-01 archived:false`
- `monorepo tooling language:TypeScript stars:>5000 in:readme`

## 代码（Code）

- `repo:owner/name`：限定仓库
- `org:xxx` / `user:xxx`：限定组织/用户
- `language:Go`：限定语言（Code Search 也支持）
- `filename:pubspec.yaml` / `filename:Cargo.toml`：限定文件名
- `path:lib/` / `path:src/`：限定路径
- `extension:dart` / `extension:ts`：限定扩展名
- `in:file` / `in:path`：限定匹配范围（不同搜索入口支持略有差异）

示例：
- `repo:flutter/flutter filename:pubspec.yaml cupertino_icons`
- `org:vercel filename:tsconfig.json \"paths\"`
- `language:Python path:src \"def main\"`

## Issue / PR（Issues）

- `repo:owner/name`：限定仓库
- `is:issue` / `is:pr`：Issue 或 PR
- `is:open` / `is:closed`：状态
- `label:bug` / `label:\"good first issue\"`：标签
- `author:xxx` / `assignee:xxx` / `mentions:xxx`：相关人
- `created:>2025-01-01` / `updated:>2025-01-01`：时间范围

示例：
- `repo:owner/name is:issue is:open label:bug`
- `org:flutter is:pr is:open \"breaking change\"`

## 实用技巧

- 先用 `repos` 找“代表仓库”→ 再用 `code` 在这些仓库里定点找实现。
- 把你的目标具象化成“关键词 + 约束”：比如“离线同步”“SQLite 迁移”“多端”“插件”等。
- 遇到限流：设置 `GITHUB_TOKEN`，并缩小 `--pages/--per-page`。

