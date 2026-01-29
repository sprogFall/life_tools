# iOS 26 设计系统优化方案

## 阶段一：Material 组件替换 (预计 2-3 小时)

### 1.1 替换 CircularProgressIndicator → CupertinoActivityIndicator

**目标文件** (10个):

* overcooked\_image.dart

* overcooked\_wishlist\_tab.dart

* overcooked\_meal\_tab.dart

* overcooked\_recipes\_tab.dart

* overcooked\_recipe\_edit\_page.dart

* overcooked\_image\_viewer\_page.dart

* overcooked\_recipe\_detail\_page.dart

* overcooked\_calendar\_tab.dart

* sync\_settings\_page.dart

* backup\_restore\_page.dart

### 1.2 替换 TextButton → CupertinoButton

**目标文件**:

* overcooked\_recipe\_edit\_page.dart (第145行)

***

## 阶段二：文本样式标准化 (预计 4-6 小时)

### 2.1 创建文本样式访问器

在 IOS26Theme 中添加静态访问器：

```dart
static TextStyle get displayLarge => _textTheme.displayLarge!;
static TextStyle get headlineMedium => _textTheme.headlineMedium!;
static TextStyle get titleMedium => _textTheme.titleMedium!;
static TextStyle get bodyLarge => _textTheme.bodyLarge!;
static TextStyle get bodyMedium => _textTheme.bodyMedium!;
static TextStyle get bodySmall => _textTheme.bodySmall!;
static TextStyle get labelLarge => _textTheme.labelLarge!;
```

### 2.2 按模块替换硬编码文本样式

**优先级排序**:

1. Core 模块 (sync, backup, messages, settings)
2. Tools 模块 - stockpile\_assistant
3. Tools 模块 - overcooked\_kitchen
4. Tools 模块 - work\_log, tag\_manager

**替换模式**:

```dart
// Before
Text('标题', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: IOS26Theme.textPrimary))

// After
Text('标题', style: IOS26Theme.titleMedium)
```

***

## 阶段三：间距与圆角规范化 (预计 3-4 小时)

### 3.1 在 IOS26Theme 中添加规范常量

```dart
// 间距规范
static const double spacingXs = 4;
static const double spacingSm = 8;
static const double spacingMd = 12;
static const double spacingLg = 16;
static const double spacingXl = 20;
static const double spacingXxl = 28;

// 圆角规范
static const double radiusSm = 8;
static const double radiusMd = 12;
static const double radiusLg = 16;
static const double radiusXl = 20;
static const double radiusFull = 999;

// 卡片内边距
static const EdgeInsets cardPadding = EdgeInsets.all(16);
static const EdgeInsets listItemPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
```

### 3.2 替换硬编码值

* 圆角: 统一使用 IOS26Theme.radiusXxx

* 间距: 统一使用 IOS26Theme.spacingXxx

***

## 阶段四：AppBar 组件统一 (预计 2 小时)

### 4.1 扩展 IOS26AppBar 功能

添加对首页场景的支持：

```dart
// 添加新构造函数
const IOS26AppBar.home({
  required this.title,
  this.onSettingsPressed,
}) : showBackButton = false,
     actions = null,
     leading = null;
```

### 4.2 替换自定义实现

* home\_page.dart: 替换 \_buildAppBar

* stockpile\_tool\_page.dart: 替换 \_StockpileAppBar

***

## 阶段五：图标统一 (预计 1-2 小时)

### 5.1 替换 Material Icons 为 CupertinoIcons

搜索并替换 `Icons.` 为对应的 `CupertinoIcons.`:

* Icons.arrow\_back\_ios\_new\_rounded → CupertinoIcons.back

* Icons.add → CupertinoIcons.add

* Icons.settings/gear → CupertinoIcons.gear

* 其他...

***

## 实施顺序建议

1. **第一周**: 阶段一 (Material组件替换) + 阶段五 (图标统一)
2. **第二周**: 阶段二 (文本样式标准化)
3. **第三周**: 阶段三 (间距圆角规范化)
4. **第四周**: 阶段四 (AppBar统一) + 全面测试

***

## 预期成果

* ✅ 所有加载指示器统一为 CupertinoActivityIndicator

* ✅ 所有按钮统一为 CupertinoButton

* ✅ 文本样式 100% 使用主题定义

* ✅ 间距圆角遵循设计规范

* ✅ 统一的 AppBar 组件

* ✅ 纯 iOS 风格，无 Material 组件残留

