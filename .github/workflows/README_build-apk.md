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

### 2. main 分支推送（需要标签）

当代码推送到 `main` 分支时，需要在 commit message 中包含特定标签才会触发构建。

#### 构建 Debug APK

在 commit message 中添加 `[build-apk]` 或 `[build-apk:debug]`：

```bash
git commit -m "[build-apk] 修复登录问题"
# 或
git commit -m "[build-apk:debug] 修复登录问题"
```

#### 构建 Release APK

在 commit message 中添加 `[build-apk:release]`：

```bash
git commit -m "[build-apk:release] 发布 v1.0.0"
```

## 构建规则总结

| 分支 | 触发条件 | 构建类型 |
|------|---------|---------|
| `dev` | 任何推送 | Debug（自动） |
| `main` | commit message 包含 `[build-apk]` | Debug |
| `main` | commit message 包含 `[build-apk:debug]` | Debug |
| `main` | commit message 包含 `[build-apk:release]` | Release |

## 忽略文件

以下文件的变更不会触发构建：
- `**.md` - 所有 Markdown 文件
- `.gitignore`
- `.claude/**` - Claude 配置目录

## 输出产物

### APK 命名规则

- **Debug**: `life_tools-debug-{commit_sha}.apk`
- **Release**: `life_tools-release-{commit_sha}.apk`

### 下载位置

构建完成后，APK 文件会作为 artifact 上传，保留 30 天。可以在以下位置下载：

1. 进入 GitHub 仓库的 **Actions** 标签页
2. 选择对应的 workflow 运行记录
3. 在 **Artifacts** 部分下载 APK

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

### 测试环境（main 分支 + debug）

```bash
# 合并到 main 并构建 debug 包进行测试
git checkout main
git merge dev
git commit -m "[build-apk] 合并用户管理功能"
git push origin main
# ✅ 触发 debug 构建
```

### 生产发布（main 分支 + release）

```bash
# 正式发布，构建 release 包
git checkout main
git commit -m "[build-apk:release] 发布 v1.2.0 - 新增用户管理功能"
git push origin main
# ✅ 触发 release 构建
```

## 环境变量

- `FLUTTER_VERSION`: `3.38.6` - Flutter SDK 版本

## 依赖

- **Java**: Temurin JDK 17
- **Flutter**: 稳定版通道

## 故障排查

### 构建未触发

1. **dev 分支**: 检查是否正确推送到 dev 分支
2. **main 分支**: 检查 commit message 是否包含正确的标签
3. 检查修改的文件是否都在忽略列表中

### 构建失败

1. 查看 Actions 日志中的错误信息
2. 检查 `pubspec.yaml` 依赖是否正确
3. 确认 Flutter 版本是否兼容

## 最佳实践

1. **开发阶段**: 在 dev 分支上工作，自动构建 debug 包进行测试
2. **测试验证**: 合并到 main 前先在 dev 分支验证
3. **发布前检查**: 使用 `[build-apk]` 在 main 分支构建 debug 包进行最终测试
4. **正式发布**: 确认无误后使用 `[build-apk:release]` 构建 release 包

## 注意事项

⚠️ **重要提示**：
- dev 分支的每次推送都会触发构建，请确保代码可编译
- release 构建需要确保代码经过充分测试
- APK artifacts 保留 30 天后自动删除
