# Failure Records

本目录按模块记录 `pre-push`、`exec-push`、`post-push` 中发现的失败信息。

## 使用规则

- 开发前先查看当前模块及相关模块的记录，例如 `failure-records/flutter/`、`failure-records/backend/`。
- 脚本检测到失败时会自动生成 `状态: 待归纳` 的记录文件。
- AI 修复问题后，需要补全记录中的 `精简错误信息`、`解决方案`、`预防方案`。
- 记录中不要写入密钥、Token、密码等敏感信息。

## 模块目录

- `flutter/`: Flutter 应用、平台工程、测试、构建相关失败。
- `backend/`: 后端服务与后端测试失败。
- `dashboard/`: Dashboard 前端测试与构建失败。
- `docs/`: 文档流程相关失败。
- `repo/`: 跨模块、发布脚本、仓库配置或无法明确归属的失败。
