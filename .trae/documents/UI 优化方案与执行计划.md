我将分两步执行您的请求：首先创建优化方案文档，经确认后执行代码改造。

## 第一阶段：创建优化方案文档

我将创建一个名为 `docs/UI_OPTIMIZATION_PLAN.md` 的文件，详细阐述以下优化内容：

### 1. 核心架构统一 (Core Architecture)
- **统一导航 (AppNavigator)**: 封装 `Navigator.of(context).push(CupertinoPageRoute(...))`，提供简洁的 `AppNavigator.push(context, page)` 和 `AppNavigator.pushReplacement` 等接口。
- **统一弹窗 (AppDialogs)**: 创建 `AppDialogs` 类，集中管理 `showCupertinoDialog` 和 `showCupertinoModalPopup`，提供标准化的 `showInfo`（提示）、`showConfirm`（确认）、`showInput`（输入）和 `showLoading`（加载中）方法，杜绝样式不统一。
- **统一脚手架 (AppScaffold)**: 提取首页的“渐变光晕背景”逻辑为通用 `AppScaffold` 组件，使所有二级页面（如设置页、工具页）都能拥有与首页一致的高级质感，解决“界面不够美观”的问题。

### 2. 视觉与交互升级 (Visual & Interaction)
- **色彩微调 (Color Palette)**:
  - 优化 `IOS26Theme`，引入更细腻的语义化颜色（如 `surfaceVariant`）。
  - 调整卡片阴影（Shadow）和边框（Border）的不透明度，使其更具通透感。
- **组件标准化**:
  - **GlassContainer**: 增强毛玻璃效果，增加微弱的白色内描边，提升精致度。
  - **SectionHeader**: 封装设置页中的“小标题”，统一间距和字体样式。
  - **SettingRow**: 统一设置项的高度、图标大小和点击反馈。

### 3. 代码重构计划 (Refactoring)
- **重构范围**:
  - `lib/core/ui/`：新建核心 UI 组件库。
  - `lib/pages/`：重构首页及所有设置页，应用新组件。
  - `lib/core/theme/`：更新主题配置。

## 第二阶段：执行代码优化

在您确认上述方案文档后，我将按照以下步骤进行代码修改：

1.  **创建基础库**:
    - 新建 `lib/core/ui/app_navigator.dart`
    - 新建 `lib/core/ui/app_dialogs.dart`
    - 新建 `lib/core/ui/app_scaffold.dart`
    - 新建 `lib/core/ui/section_header.dart`
2.  **升级主题**: 修改 `lib/core/theme/ios26_theme.dart`，优化颜色参数。
3.  **全局替换**:
    - 将 `Navigator.push` 替换为 `AppNavigator.push`。
    - 将散落在各页面的 `showCupertinoDialog` 替换为 `AppDialogs` 调用。
    - 将 `Scaffold` 替换为 `AppScaffold`，移除重复的 `SafeArea` 和背景代码。
4.  **验证**: 运行应用，检查页面跳转流畅度、弹窗样式一致性及整体视觉效果。
