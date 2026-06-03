# Build APK GitHub Actions 说明

## 概述

此 workflow 采用双轨构建：

- `main` / `dev` 普通 push：按原逻辑自动构建自测 APK，并发布为 prerelease。
- `vMAJOR.MINOR.PATCH` Tag push：构建正式 Release APK，安装包版本号来自 tag，客户端更新只识别这类正式 Release。

这样日常自测打包和正式发版打包互不影响。

## 触发条件

### 自测包

```bash
git push origin dev
git push origin main
```

- `dev`：构建 debug APK。
- `main`：构建 release APK。
- 发布 tag：`apk-{branch}-{short_sha}`。
- Release 类型：prerelease。
- 客户端更新检查会忽略 prerelease，因此不会拉到自测包。

### 正式发版包

```bash
bash scripts/release-apk.sh 1.2.3
```

- 只接受 `vMAJOR.MINOR.PATCH` 格式。
- 一键脚本会先更新 `VERSION` 文件并 push 发版提交，再创建并 push 正式 tag。
- 脚本会等待 GitHub Action 结束，并输出 Release 页面和 APK 下载地址。
- 构建 release APK。
- 发布 tag：`v1.2.3`。
- Release 类型：正式 Release。
- 客户端“关于 -> 检查更新”只会识别这类正式包。

## 版本号规则

- 自测包使用 `APP_VERSION=1.0.0`，避免被当作正式版本。
- 正式 tag `v1.2.3` 会生成安装包版本名 `1.2.3`。
- `versionCode` 使用 GitHub Actions 的 `run_number`，保证后续版本可覆盖安装。
- 正式构建参数示例：
  - `--build-name=1.2.3`
  - `--build-number=<run_number>`
  - `--dart-define=APP_VERSION=1.2.3`

## 输出产物

### 自测包

- Debug：`life_tools-debug-{short_sha}.apk`
- Release：`life_tools-release-{short_sha}.apk`
- Release tag：`apk-{branch}-{short_sha}`
- 类型：prerelease

### 正式包

- APK 文件名：`life_tools-release-v1.2.3.apk`
- GitHub Release Tag：`v1.2.3`
- 类型：正式 Release

## 客户端更新

应用内“关于 -> 检查更新”会请求：

```text
https://api.github.com/repos/sprogFall/life_tools/releases/latest
```

客户端只接受：

- 正式 Release（忽略 draft / prerelease）
- Tag 必须为 `vMAJOR.MINOR.PATCH`
- Release assets 中存在 `.apk`
- Release 版本大于当前安装包版本

## 依赖

- Java: Temurin JDK 17
- Flutter: `3.38.6`
- GitHub CLI: GitHub Hosted Runner 预装，用于创建/更新 Release asset
- Workflow 权限：`contents: write`
