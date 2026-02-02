# UI 优化方案与执行计划

## 1. 核心架构统一 (Core Architecture)

### 统一导航 (AppNavigator)
- **现状**: 目前使用 `Navigator.of(context).push(CupertinoPageRoute(...))`，代码重复且冗余。
- **方案**: 封装 `AppNavigator` 类。
- **接口**:
  - `push(context, page)`
  - `pushReplacement(context, page)`
  - `pop(context)`

### 统一弹窗 (AppDialogs)
- **现状**: 各页面自行调用 `showCupertinoDialog`，样式（圆角、按钮颜色）可能存在细微差异，且代码重复。
- **方案**: 创建 `AppDialogs` 类，集中管理所有弹窗。
- **接口**:
  - `showInfo(context, title, content)`: 简单提示。
  - `showConfirm(context, title, content, onConfirm, isDestructive)`: 确认操作。
  - `showInput(context, title, placeholder, onConfirm)`: 输入框弹窗。
  - `showLoading(context)`: 全局加载中。

### 统一脚手架 (AppScaffold)
- **现状**: 仅首页拥有精美的“渐变光晕”背景，其他页面多为纯色背景，显得单调且不统一。
- **方案**: 提取首页背景逻辑为 `AppScaffold` 组件。
- **特性**:
  - 自动包含背景渐变装饰（可配置是否显示）。
  - 统一处理 `SafeArea`。
  - 统一背景色管理。

## 2. 视觉与交互升级 (Visual & Interaction)

### 色彩微调 (Color Palette)
- **优化**:
  - 引入 `surfaceVariant` (略深的背景色) 增加层次感。
  - 调整 Shadow 颜色，使其更通透。
  - 增加 `glassBorderColor` 的可见度，提升精致感。

### 组件标准化
- **GlassContainer**: 统一圆角、模糊度、内描边。
- **SectionHeader**: 统一设置页中“分组标题”的样式（间距、字体）。
- **IOS26SettingsRow**: 确保所有设置项高度、点击态一致。

## 3. 代码重构计划 (Refactoring)

### 步骤
1.  **创建基础库**:
    - `lib/core/ui/app_navigator.dart`
    - `lib/core/ui/app_dialogs.dart`
    - `lib/core/ui/app_scaffold.dart`
    - `lib/core/ui/section_header.dart`
2.  **升级主题**: 修改 `lib/core/theme/ios26_theme.dart`。
3.  **全局替换**:
    - 重构 `HomePage`。
    - 重构 `AiSettingsPage`。
    - 重构 `SyncSettingsPage`。
    - 重构 `ToolManagementPage` / `BackupRestorePage` / `ObjStoreSettingsPage`。
4.  **验证**: 运行测试。
