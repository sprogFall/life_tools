# Repository Guidelines

## Agent注意事项
1. 永远用中文回答我

## 开发原则

1. **TDD（测试驱动开发）**：编写功能代码之前，先编写测试类，覆盖尽可能多的场景。每次修改后必须执行测试用例，并及时补充新功能所需的测试案例
2. **简约原则**：不要过度设计，保持代码简洁，避免不必要的复杂化
3. **零容忍重复**：必须复用代码，杜绝重复逻辑
4. **中文响应**：始终使用中文进行交流和回复
5. **改动验证要求**：
   - 若本次改动涉及 **Flutter 侧代码/构建相关文件**（如 `lib/**`、`test/**`、平台代码 `android/**`/`ios/**`/`macos/**`/`windows/**`/`linux/**`、以及 `pubspec.yaml` 等），必须在交付前执行并通过：`flutter analyze` 与 `flutter test`
   - 若本次改动 **仅涉及后端服务**（`backend/**`）且未改动任何 Flutter 相关目录/配置，则无需执行 `flutter analyze` / `flutter test`；但必须执行对应后端的测试（例如：`cd backend/sync_server && .venv/bin/pytest`）
   - 若本次改动仅为“文档类变更”（如 `README.md`、`docs/**`、`examples/**`、`*.md` 等），可不执行 `flutter analyze` / `flutter test`
   - 若仅进行 Git 操作（如生成/整理 `git commit`，且未改动任何代码文件），可不执行 `flutter analyze` / `flutter test`

## 项目概述

这是一个名为 "life_tools" 的 Flutter 应用，支持 Android、iOS、Web、Linux、macOS 和 Windows 多平台。使用 Dart SDK ^3.10.7。
数据全部记录在应用本地（SQLite）
## 常用命令

所有命令均兼容 Windows 系统（PowerShell/CMD）。

### Linux 中 Flutter 的常见调用方式

在 Linux 下若 `flutter` 不在 `PATH`，可使用以下几种方式调用（任选其一）：

- 已加入 `PATH`：直接使用 `flutter ...`
- 发行版/镜像预装在 `/opt`：使用 `/opt/flutter/bin/flutter ...`
- 手动解压在用户目录：使用 `~/flutter/bin/flutter ...`
- 安装在 `/usr/local`：使用 `/usr/local/flutter/bin/flutter ...`
- 临时加入 `PATH`（当前终端有效）：`export PATH="$PATH:/opt/flutter/bin"`

```bash
# 安装依赖
flutter pub get

# 运行应用（调试模式）
flutter run

# 在指定设备上运行
flutter run -d chrome    # Web
flutter run -d windows   # Windows
flutter run -d android   # Android 模拟器/真机

# 构建发布版本
flutter build apk        # Android
flutter build ios        # iOS
flutter build web        # Web

# 运行所有测试（开发过程中频繁使用）
flutter test

# 运行单个测试文件
flutter test test/widget_test.dart

# 运行测试并生成覆盖率报告
flutter test --coverage

# 静态代码分析
flutter analyze

# 格式化代码
dart format .
```

## 架构

- **lib/main.dart** - 应用入口，包含 `MyApp` 根组件和 `MyHomePage` 主页面
- **test/** - 使用 `flutter_test` 包的 Widget 测试
- 使用 Material Design（`uses-material-design: true`）
- 通过 `flutter_lints` 包进行代码检查（配置在 `analysis_options.yaml`）

## AI 调用（公共入口）

项目在 `lib/main.dart` 已注入 `AiService`，业务侧通过 Provider 获取后调用 `chatText(...)` 或 `chat(...)` 即可。

示例代码请查看：`examples/ai.md`

## 资源存储（公共入口）

项目在 `lib/main.dart` 已注入 `ObjStoreService`，业务侧通过 Provider 获取后调用 `uploadBytes(...)` 或 `resolveUri(...)` 即可。

示例代码请查看：`examples/objStore.md`

## 标签调用（公共入口）

项目在 `lib/main.dart` 已注入 `TagService`，业务侧通过 Provider 获取后调用相关方法即可。

示例代码请查看：`examples/tags.md`

## 消息通知（公共入口）

项目在 `lib/main.dart` 已注入 `MessageService`，业务侧通过 Provider 获取后调用相关方法即可。

示例代码请查看：`examples/message.md`

## UI 设计规范

开发页面时必须遵守 iOS 26 风格的设计主题，包括颜色、按钮样式、表单规范等。

详细规范请查看：`examples/ui.md`

### iOS 26 统一规范（补充）

- 文本样式：业务代码禁止硬编码 `TextStyle(...)`，统一使用 `IOS26Theme` 的文本样式访问器（`displayLarge` / `headlineMedium` / `titleLarge` / `titleMedium` / `titleSmall` / `bodyLarge` / `bodyMedium` / `bodySmall` / `labelLarge`）。
- 间距与圆角：统一使用 `IOS26Theme.spacingXxx` 与 `IOS26Theme.radiusXxx` 常量。
- 颜色常量：业务代码禁止使用 `Colors.white` 等硬编码色值，统一使用 `IOS26Theme` 的语义化颜色（如 `IOS26Theme.surfaceColor` / `IOS26Theme.backgroundColor` / `IOS26Theme.textPrimary` 等）。
- 组件统一：加载使用 `CupertinoActivityIndicator`；按钮使用 `CupertinoButton`；图标使用 `CupertinoIcons`；避免 `TextButton` / `IconButton` / `InkWell` / `CircularProgressIndicator` / `Divider` 等 Material 组件（如有必要需在代码注释说明原因）。
- AppBar：页面统一使用 `IOS26AppBar`；首页使用 `IOS26AppBar.home(onSettingsPressed: ...)`；当 `IOS26AppBar` 放在 `SafeArea` 内时必须设置 `useSafeArea: false` 避免重复内边距。
- 交互尺寸：图标/导航类按钮的 `CupertinoButton` 必须设置 `minimumSize: IOS26Theme.minimumTapSize`，并按需保持 `padding: EdgeInsets.zero`。

### 明暗主题按钮/图标规范（新增）

- 按钮颜色统一走语义 token：使用 `IOS26Theme.buttonColors(IOS26ButtonVariant.xxx)`；业务代码禁止直接写 `CupertinoButton(color: IOS26Theme.xxx)`。
- 按钮语义建议：主流程提交用 `primary`；普通次操作用 `secondary`；弱化操作（如“取消/复制/选择文件”）用 `ghost`；危险次操作用 `destructive`；高风险主操作（如“确认恢复/永久删除”）用 `destructivePrimary`。
- 图标颜色统一走语义 tone：普通图标使用 `IOS26Theme.iconColor(IOS26IconTone.xxx)`；带底图标胶囊使用 `IOS26Theme.iconChipColors(IOS26IconTone.xxx)`。
- 明暗模式适配原则：不要在页面内手写 alpha 方案（如 `primaryColor.withValues(alpha: ...)`）来拼按钮状态，统一通过语义 token 让亮暗两套自动切换。

## 代码规范（2026-02-04 代码审查沉淀）

### 异常处理

- 禁止空吞异常：不允许出现 `catch (_) {}`。至少使用 `devLog(...)` 记录（仅 Debug 输出），必要时给用户明确反馈（Dialog/Toast）。
- 日志脱敏：严禁在日志/异常信息中输出密钥/令牌/自定义 Header 等敏感信息；`devLog` 的 message/error 也必须遵守。

### 国际化（i18n）

- UI 文案禁止硬编码：页面标题、按钮文案、空态文案等必须使用 `AppLocalizations`（优先 `common_*`，模块内使用 `xxx_*` 命名）。
- 新增文案流程：同步更新 `lib/l10n/app_en.arb`、`lib/l10n/app_en_US.arb`、`lib/l10n/app_zh.arb`、`lib/l10n/app_zh_CN.arb`，并执行 `/opt/flutter/bin/flutter gen-l10n` 生成 Dart 文件。
- Widget 测试统一包裹：测试中优先使用 `test/test_helpers/test_app_wrapper.dart`，避免缺少 `localizationsDelegates` 导致页面崩溃。

### 样式与复用

- 禁止硬编码 `EdgeInsets.all(8)`：统一替换为 `EdgeInsets.all(IOS26Theme.spacingSm)` 或更语义化的间距组合。
- 工具页返回首页按钮复用：AppBar leading 的“首页”入口统一使用 `IOS26HomeLeadingButton`，避免重复 Row/样式/交互尺寸逻辑。

### 规范守护（测试）

- 设计/规范类约束通过测试守护：`test/design/no_empty_catch_blocks_test.dart`、`test/design/no_edge_insets_all_8_test.dart`、`test/design/no_colors_white_test.dart`、`test/design/no_direct_ios26_button_color_test.dart`。

## 安全与隐私规范（补充）

1. **敏感信息最小暴露**：
   - 严禁在日志/异常信息中输出密钥类信息（如 AI API Key、七牛 AK/SK、同步 Token/自定义 Header）
   - 备份/导出/分享必须显式提供“包含敏感信息”的开关，并在 UI/文档中提示风险；默认值按产品需求决定（当前为方便迁移默认开启）
2. **路径安全**：
   - 任何把 `key/path` 拼接到本地目录（`baseDir`）的逻辑，必须保证最终路径仍在 `baseDir` 内（例如使用 `path.isWithin` 做边界校验），禁止 `../` 穿越
3. **网络安全默认值**：
   - 外部服务 URL 默认使用 `https`；若允许 `http`（如内网调试），需在 UI/文档明确提醒风险

## 提交前检查（补充）

- 变更 Flutter 侧（`lib/**`、`test/**`、平台工程或 `pubspec.yaml`）：必须执行并通过 `flutter analyze` 与 `flutter test`
- 仅变更后端（`backend/**`）且未改动 Flutter：无需执行 `flutter analyze` / `flutter test`；但必须执行对应后端测试
- 建议在提交前执行 `dart format .` 保持统一格式
