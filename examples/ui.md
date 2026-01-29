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

## 组件统一（iOS 26 风格）

- 加载：`CupertinoActivityIndicator`
- 按钮：`CupertinoButton`
- 图标：`CupertinoIcons`
- 禁止使用：`TextButton` / `IconButton` / `InkWell` / `CircularProgressIndicator` / `Divider` 等 Material 组件（确需保留时在代码注释说明原因）。

## AppBar 规范

- 常规页面统一使用 `IOS26AppBar`
- 首页使用 `IOS26AppBar.home(onSettingsPressed: ...)`
- 当 `IOS26AppBar` 处于 `SafeArea` 内时，必须设置 `useSafeArea: false`

## 交互尺寸规范

- 图标/导航类 `CupertinoButton` 必须设置：`minimumSize: IOS26Theme.minimumTapSize`

## 可复用组件（优先复用，避免重复造轮子）

- `IOS26AppBar`：iOS 26 毛玻璃导航栏（支持返回按钮 / actions）
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

## 按钮颜色使用规范

**主要操作按钮（Primary）：**
- 背景色：`IOS26Theme.primaryColor`
- 文字色：`Colors.white`
- 适用场景：提交、确认、保存等主要操作
- 示例：AI录入页面的"提交给AI"按钮

**次要操作按钮（Secondary）：**
- 背景色：`IOS26Theme.textTertiary.withValues(alpha: 0.3)` （半透明浅灰）
- 图标色：`IOS26Theme.textSecondary`
- 适用场景：取消、清空、删除等辅助操作
- 示例：AI录入页面的清空（垃圾桶）、取消（×）按钮

**按钮圆角：**
- 优先使用 `IOS26Theme.radiusMd` 或 `IOS26Theme.radiusLg`

**按钮内边距：**
- 主要按钮：`EdgeInsets.symmetric(vertical: IOS26Theme.spacingLg)`
- 图标按钮：`EdgeInsets.symmetric(horizontal: IOS26Theme.spacingLg, vertical: IOS26Theme.spacingLg)`

## 表单字段标题规范

- 所有表单输入项必须展示"外置字段标题"（如：放在输入框上方/卡片标题/列表项左侧），禁止仅用 `placeholder` 作为字段名
- `placeholder` 仅可用于示例/提示（如"如：牛奶"），不得影响用户在输入后识别字段含义
- 数据较少/强相关字段可做紧凑排版（同行多列），但每个字段仍需有清晰标题
