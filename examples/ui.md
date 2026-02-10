# UI 设计规范

## 主题颜色

项目使用 iOS 26 风格的设计主题，所有颜色定义在 `lib/core/theme/ios26_theme.dart` 中：

**主色调：**
- `IOS26Theme.primaryColor` - 主要操作色（蓝色 #007AFF）
- `IOS26Theme.secondaryColor` - 次要操作色（紫色 #5856D6）

**文字颜色：**
- `IOS26Theme.textPrimary` - 主要文字（深色 #1C1C1E）
- `IOS26Theme.textSecondary` - 次要文字（灰色 #8E8E93）
- `IOS26Theme.textTertiary` - 辅助文字（浅灰 #C7C7CC）

**工具颜色：**
- `IOS26Theme.toolBlue` - 工具蓝（#007AFF）
- `IOS26Theme.toolGreen` - 工具绿（#34C759）
- `IOS26Theme.toolOrange` - 工具橙（#FF9500）
- `IOS26Theme.toolRed` - 工具红（#FF3B30）
- `IOS26Theme.toolPurple` - 工具紫（#5856D6）
- `IOS26Theme.toolPink` - 工具粉（#FF2D55）

### 颜色使用原则

- 业务代码禁止使用 `Colors.white` 等硬编码色值，统一使用 `IOS26Theme` 的语义化颜色（如 `IOS26Theme.surfaceColor` / `IOS26Theme.backgroundColor` / `IOS26Theme.textPrimary` 等）。

## 文本样式（统一使用 IOS26Theme）

业务代码禁止硬编码 `TextStyle(...)`，统一使用 `IOS26Theme` 文本样式访问器：

- `IOS26Theme.displayLarge` - 34pt, w700：页面主标题/品牌名
- `IOS26Theme.headlineMedium` - 22pt, w600：卡片组标题
- `IOS26Theme.titleLarge` - 17pt, w600：列表项/卡片标题
- `IOS26Theme.titleMedium` - 16pt, w600：次级标题
- `IOS26Theme.titleSmall` - 15pt, w600：小节标题
- `IOS26Theme.bodyLarge` - 17pt, w400：正文
- `IOS26Theme.bodyMedium` - 15pt, w400：次要正文
- `IOS26Theme.bodySmall` - 13pt, w400：辅助说明
- `IOS26Theme.labelLarge` - 15pt, w500：按钮文字

```dart
Text('标题', style: IOS26Theme.titleLarge);
Text('正文', style: IOS26Theme.bodyLarge);
Text('提示', style: IOS26Theme.bodySmall);
```

## 间距与圆角规范

**间距：** `IOS26Theme.spacingXs/Sm/Md/Lg/Xl/Xxl/Xxxl`
**圆角：** `IOS26Theme.radiusSm/Md/Lg/Xl/Xxl/Full`

```dart
const SizedBox(height: IOS26Theme.spacingLg);
Padding(padding: const EdgeInsets.all(IOS26Theme.spacingMd));
BorderRadius.circular(IOS26Theme.radiusXl);
```

- 禁止硬编码 `EdgeInsets.all(8)`，统一替换为 `EdgeInsets.all(IOS26Theme.spacingSm)` 或更语义化的间距组合。

## 组件统一（iOS 26 风格）

- 加载：`CupertinoActivityIndicator`
- 按钮：统一使用 `IOS26Button` / `IOS26IconButton`（组件内部封装 `CupertinoButton`）
- 图标：`CupertinoIcons`
- 非按钮图标：统一使用 `IOS26Icon`（优先 `tone`，仅动态场景允许 `color` 覆盖）
- Markdown：统一使用 `IOS26MarkdownView` / `IOS26MarkdownBody`（禁止直接使用 `Markdown` / `MarkdownBody`）
- 图片：统一使用 `IOS26Image.file` / `IOS26Image.network` / `IOS26Image.memory`（禁止直接使用 `Image.file` / `Image.network` / `Image.memory`）
- 禁止使用：`TextButton` / `IconButton` / `InkWell` / `CircularProgressIndicator` / `Divider` 等 Material 组件（确需保留时在代码注释说明原因）

## AppBar 规范

- 常规页面统一使用 `IOS26AppBar`
- 首页使用 `IOS26AppBar.home(onSettingsPressed: ...)`
- 当 `IOS26AppBar` 处于 `SafeArea` 内时，必须设置 `useSafeArea: false`
- 工具页返回首页按钮统一使用 `IOS26HomeLeadingButton`，避免重复 Row/样式/交互尺寸逻辑

## 交互尺寸规范

- 图标/导航类按钮统一使用 `IOS26Theme.minimumTapSize`
- 优先由 `IOS26Button` / `IOS26IconButton` 默认值承接，特殊场景再覆盖

## 按钮与图标规范（明暗主题适配）

### 按钮规范

- 页面层禁止 `CupertinoButton(color: ...)`：统一使用 `IOS26Button` / `IOS26IconButton`，由组件内部处理明暗两套配色与前景色注入。
- 按钮语义通过 `variant` 表达：
  - `primary`：主流程提交
  - `secondary`：普通次操作
  - `ghost`：弱化操作（如"取消/复制/选择文件"）
  - `destructive`：危险次操作
  - `destructivePrimary`：高风险主操作（如"确认恢复/永久删除"）
- 页面层禁止手写明暗适配：不要在页面内手写 alpha（如 `primaryColor.withValues(alpha: ...)`）拼按钮状态；若确有特殊背景需求，仅允许通过 `IOS26Button(backgroundColor: ...)` 显式覆盖并注明原因。
- 按钮内容统一复用组件：
  - 按钮内文本：`IOS26ButtonLabel`
  - 按钮内图标：`IOS26ButtonIcon`
  - 按钮内加载态：`IOS26ButtonLoadingIndicator`
  - 页面层禁止直接引用 `xxxButton.foreground`

### 图标规范

- 页面层禁止直接 `Icon(color: ...)`，统一使用 `IOS26Icon`
- 图标语义通过 `tone` 表达：
  - `primary/secondary`：普通图标
  - `accent`：强调图标
  - `warning/danger/success`：风险态图标
- 仅动态场景允许 `color` 覆盖

## 布局规范

- `SingleChildScrollView` 的 `child` 直系使用 `Column` 时，必须声明 `crossAxisAlignment: CrossAxisAlignment.stretch`（或等效显式全宽包裹），避免短文案导致卡片/容器未占满页面宽度。

## 可复用组件（优先复用，避免重复造轮子）

- `IOS26AppBar`：iOS 26 毛玻璃导航栏（支持返回按钮 / actions）
- `IOS26HomeLeadingButton`：工具页返回首页按钮
- `IOS26Button` / `IOS26IconButton`：统一按钮组件
- `IOS26ButtonLabel` / `IOS26ButtonIcon` / `IOS26ButtonLoadingIndicator`：按钮内容组件
- `IOS26Icon`：统一图标组件
- `IOS26MarkdownView` / `IOS26MarkdownBody`：统一 Markdown 组件
- `IOS26Image`：统一图片组件
- `GlassContainer`：毛玻璃卡片容器

```dart
import 'package:flutter/material.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Column(
        children: [
          IOS26AppBar(title: '标题', showBackButton: true),
          SizedBox(height: 12),
          GlassContainer(child: Text('内容')),
        ],
      ),
    );
  }
}
```

## 表单字段标题规范

- 所有表单输入项必须展示"外置字段标题"（如：放在输入框上方/卡片标题/列表项左侧），禁止仅用 `placeholder` 作为字段名
- `placeholder` 仅可用于示例/提示（如"如：牛奶"），不得影响用户在输入后识别字段含义
- 数据较少/强相关字段可做紧凑排版（同行多列），但每个字段仍需有清晰标题
