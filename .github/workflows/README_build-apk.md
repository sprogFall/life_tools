# Build APK GitHub Actions 说明

## 概述

此 workflow 只在手动推送版本 Tag 时构建 Android Release APK，并把 APK 挂到同名 GitHub Release。客户端更新检查只读取 GitHub 的 latest 正式 Release，因此不会把普通分支 push 当成可更新版本。

## 触发条件

只支持 `vMAJOR.MINOR.PATCH` 格式的 Tag，例如：

```bash
git tag v1.2.3
git push origin v1.2.3
```

`main` / `dev` 等分支普通 push 不会触发 APK 发布。

## 版本号规则

- Tag `v1.2.3` 会生成安装包版本名 `1.2.3`。
- `versionCode` 使用 GitHub Actions 的 `run_number`，保证后续版本可覆盖安装。
- Flutter 构建参数会传入：
  - `--build-name=1.2.3`
  - `--build-number=<run_number>`
  - `--dart-define=APP_VERSION=1.2.3`

## 输出产物

- APK 文件名：`life_tools-release-v1.2.3.apk`
- GitHub Release Tag：`v1.2.3`
- Release 类型：正式 Release，不是 prerelease
- Actions Summary 会展示 Release 页面与 APK 直链。

## 客户端更新

应用内“关于 -> 检查更新”会请求：

```text
https://api.github.com/repos/sprogFall/life_tools/releases/latest
```

客户端只接受：

- 正式 Release（忽略 draft / prerelease）
- Tag 能解析为 `vMAJOR.MINOR.PATCH`
- Release assets 中存在 `.apk`
- Release 版本大于当前安装包版本

## 依赖

- Java: Temurin JDK 17
- Flutter: `3.38.6`
- GitHub CLI: GitHub Hosted Runner 预装，用于创建/更新 Release asset
- Workflow 权限：`contents: write`

## 发布流程

1. 确保当前提交已合入目标发布代码。
2. 打版本 Tag：

```bash
git tag v1.2.3
git push origin v1.2.3
```

3. 等待 GitHub Actions 完成。
4. 在 Release 页面确认 `life_tools-release-v1.2.3.apk` 已上传。
5. 已安装旧版本的客户端可在“关于 -> 检查更新”拉取并安装。
