# Build APK GitHub Actions 说明

## 概述

此 workflow 自动构建 Android APK 文件，支持 debug 和 release 两种构建类型。

## 触发条件

### 1. dev 分支推送（自动构建 debug 包）

当代码推送到 `dev` 分支时，会自动构建 **debug APK**，无需在 commit message 中添加任何标签。

```bash
# 推送到 dev 分支即可触发
git push origin dev
```

**特点：**
- ✅ 自动触发，无需标签
- ✅ 始终构建 debug 包
- ✅ 适用于开发阶段的快速迭代

### 2. main 分支推送（自动构建 release 包）

当代码推送到 `main` 分支时，会自动构建 **release APK**，无需额外标签。

## 构建规则总结

| 分支 | 触发条件 | 构建类型 |
|------|---------|---------|
| `dev` | 任何推送 | Debug（自动） |
| `main` | 任何推送 | Release（自动） |

## 路径触发规则

仅当以下 Flutter 相关路径发生变更时才触发构建：
- `lib/**`
- `test/**`
- `android/**`
- `assets/**`
- `pubspec.yaml` / `pubspec.lock`
- `analysis_options.yaml` / `l10n.yaml`
- `.github/workflows/build-apk.yml`

因此，`backend/**`、`dashboard/**`、`docs/**`、`examples/**`、非 Android 的平台目录、Markdown-only 等改动不会触发 APK 构建。

## 流水线优化

### 并发取消（concurrency）

- 同一分支新的构建启动后，会自动取消该分支旧的运行，避免排队堆积。

### 缓存

- Flutter SDK：由 `subosito/flutter-action` 安装，并开启其内置缓存以减少重复下载。
- Gradle：`actions/setup-java` 开启 `cache: gradle`。
- Pub 包：`actions/cache@v5` 缓存 `~/.pub-cache`。

### 并行校验

- 分为 `prepare`、`flutter-analyze`、`flutter-test`、`build-apk` 四个 job。
- `flutter-test` 采用 2 分片并行执行：`--total-shards 2`。
- `build-apk` 会在 `prepare` 完成后与 analyze/test 并行启动，以尽快产出 APK。
- workflow 最终是否通过，仍由 analyze、test 与 build 共同决定；若校验失败，当前 run 仍会标记失败。

## 输出产物

### APK 命名规则

- **Debug**: `life_tools-debug-{commit_sha}.apk`
- **Release**: `life_tools-release-{commit_sha}.apk`

### 下载位置

构建完成后，workflow 会同时产出两种下载方式：

1. **直接 APK 下载链接（推荐）**
   - 在 Actions 对应 run 的 Summary 中会显示：
   - `Direct APK download`
   - `Release page`
   - 这里下载的是直接挂在 GitHub Release 上的 `.apk` 文件，不再需要先解压 artifact。
2. **Artifact 兜底下载**
   - 仍会保留一份 artifact，保留 30 天。
   - 如果需要，也可以继续在 Actions run 页面里的 **Artifacts** 区域下载。

### Release 规则

- 每次成功构建都会创建一个对应 commit 的 **prerelease**。
- Tag 规则：`apk-{branch}-{short_sha}`
- APK 资源文件仍保持原命名：
- **Debug**: `life_tools-debug-{commit_sha}.apk`
- **Release**: `life_tools-release-{commit_sha}.apk`

### 构建信息

每次构建完成后，会在 Actions 运行页面生成摘要信息，包括：

- 📍 **Branch**: 构建的分支名称
- 🏗️ **Build Type**: debug 或 release
- 📦 **APK Name**: APK 文件名
- 📏 **APK Size**: APK 文件大小
- 🔖 **Commit**: 提交的 SHA
- 👤 **Author**: 提交作者

## 使用场景

### 开发环境（dev 分支）

```bash
# 日常开发，推送到 dev 分支自动构建 debug 包
git checkout dev
git add .
git commit -m "新增用户管理功能"
git push origin dev
# ✅ 自动触发 debug 构建
```

### 生产发布（main 分支，自动 release）

```bash
# 正式发布，推送 main 自动构建 release 包
git checkout main
git commit -m "发布 v1.2.0 - 新增用户管理功能"
git push origin main
# ✅ 自动触发 release 构建
```

## 环境变量

- `FLUTTER_VERSION`: `3.38.6` - Flutter SDK 版本

## 依赖

- **Java**: Temurin JDK 17
- **Flutter**: 稳定版通道
- **GitHub CLI (`gh`)**: 由 GitHub Hosted Runner 预装，用于发布 Release asset
- **GitHub Actions**: `actions/checkout@v6`、`actions/setup-java@v5`、`actions/cache@v5`、`actions/upload-artifact@v6`，已对齐 Node 24 运行时
- **Workflow 权限**: `build-apk` job 需要 `contents: write`，以便创建 prerelease 并上传 APK

## 故障排查

### 构建未触发

1. **dev 分支**: 检查是否正确推送到 dev 分支
2. **main 分支**: 检查是否推送到了 `main`
3. **分支范围**: 当前 workflow 只监听 `main/dev`，其他分支不会触发
4. 检查修改是否命中 workflow 的路径白名单（Flutter 相关路径）

### 构建失败

1. 查看 Actions 日志中的错误信息
2. 检查 `pubspec.yaml` 依赖是否正确
3. 确认 Flutter 版本是否兼容

## 最佳实践

1. **开发阶段**: 在 dev 分支上工作，自动构建 debug 包进行测试
2. **测试验证**: 合并到 main 前先在 dev 分支验证
3. **主线发布**: main 分支保持可发布状态，推送即自动产出 release 包
4. **非主分支策略**: 若需要其他分支也参与 APK 构建，可后续增加 `workflow_dispatch` 或放开分支过滤

## 注意事项

⚠️ **重要提示**：
- dev 分支的每次推送都会触发构建，请确保代码可编译
- release 构建需要确保代码经过充分测试
- APK artifacts 保留 30 天后自动删除
- 每次成功构建还会新增一个 prerelease 条目，方便直接下载 `.apk`
- 若未来改用自建 runner，需要同步确认 runner 版本满足这些 action 对 Node 24 的最低要求
