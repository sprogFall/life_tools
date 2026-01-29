# iOS 26 设计系统优化报告

**日期**: 2026-01-29  
**审查对象**: life_tools 项目 UI/UX 全面优化  
**执行状态**: ✅ 已完成

---

## 一、优化概览

本次优化针对项目进行了全面的样式审查和重构，建立了统一的设计系统，确保颜色方案、字体层级、间距规范、组件样式等各方面达到协调一致的高水准视觉效果。

---

## 二、已完成优化项目

### ✅ 1. Material 组件替换 (阶段一)

#### 1.1 CircularProgressIndicator → CupertinoActivityIndicator
**替换范围**: 13处，覆盖10个文件

| 文件路径 | 替换数量 |
|---------|---------|
| `overcooked_image.dart` | 1 |
| `overcooked_wishlist_tab.dart` | 1 |
| `overcooked_meal_tab.dart` | 1 |
| `overcooked_recipes_tab.dart` | 1 |
| `overcooked_recipe_edit_page.dart` | 2 |
| `overcooked_calendar_tab.dart` | 1 |
| `overcooked_image_viewer_page.dart` | 3 |
| `overcooked_recipe_detail_page.dart` | 1 |
| `sync_settings_page.dart` | 1 |
| `backup_restore_page.dart` | 1 |

#### 1.2 TextButton → CupertinoButton
**替换范围**: 1处
- `overcooked_recipe_edit_page.dart`: 保存按钮已替换为 CupertinoButton

---

### ✅ 2. 额外发现的问题修复 (深度审查)

#### 2.1 IconButton → CupertinoButton
**替换范围**: 7处，覆盖4个文件

| 文件路径 | 替换数量 |
|---------|---------|
| `ios26_theme.dart` | 1 (IOS26AppBar 返回按钮) |
| `overcooked_recipe_detail_page.dart` | 2 (编辑、删除按钮) |
| `stock_item_detail_page.dart` | 3 (编辑、消耗、删除按钮) |
| `overcooked_tool_page.dart` | 1 (返回按钮) |

#### 2.2 Material Icons → CupertinoIcons
**替换范围**: 3处

| 原图标 | 新图标 | 文件 |
|-------|-------|------|
| `Icons.arrow_back_ios_new_rounded` | `CupertinoIcons.back` | ios26_theme.dart, overcooked_tool_page.dart |
| `Icons.casino_rounded` | `CupertinoIcons.shuffle` | overcooked_recipes_tab.dart, overcooked_tool_page.dart |

#### 2.3 InkWell → CupertinoButton
**替换范围**: 1处
- `overcooked_recipes_tab.dart`: 菜谱卡片点击效果

#### 2.4 Divider → Container
**替换范围**: 1处
- `overcooked_recipe_picker_sheet.dart`: 列表分隔线改为自定义 Container 实现

---

### ✅ 3. 主题系统扩展 (阶段二、三)

#### 3.1 新增文本样式静态访问器
在 `IOS26Theme` 中添加了便捷的文本样式访问器：

```dart
// 标题层级
static TextStyle get displayLarge;   // 34pt, w700 - 页面主标题
static TextStyle get displayMedium;  // 28pt, w700
static TextStyle get headlineLarge;  // 28pt, w600 - 导航栏大标题
static TextStyle get headlineMedium; // 22pt, w600 - 卡片组标题
static TextStyle get headlineSmall;  // 20pt, w600
static TextStyle get titleLarge;     // 17pt, w600 - 列表项标题
static TextStyle get titleMedium;    // 16pt, w600
static TextStyle get titleSmall;     // 15pt, w600 - 小节标题

// 正文层级
static TextStyle get bodyLarge;      // 17pt, w400 - 主要阅读文本
static TextStyle get bodyMedium;     // 15pt, w400 - 次要说明文本
static TextStyle get bodySmall;      // 13pt, w400 - 提示、标注

// 按钮文本
static TextStyle get labelLarge;     // 15pt, w500 - 按钮、链接
```

#### 3.2 新增间距规范常量
```dart
static const double spacingXs = 4;
static const double spacingSm = 8;
static const double spacingMd = 12;
static const double spacingLg = 16;
static const double spacingXl = 20;
static const double spacingXxl = 28;
static const double spacingXxxl = 36;
```

#### 3.3 新增圆角规范常量
```dart
static const double radiusSm = 8;
static const double radiusMd = 12;
static const double radiusLg = 16;
static const double radiusXl = 20;
static const double radiusXxl = 24;
static const double radiusFull = 999;
```

---

## 三、设计规范参考

### 文本样式使用指南

| 样式名称 | 字号 | 字重 | 颜色 | 用途 |
|---------|------|------|------|------|
| `displayLarge` | 34 | w700 | textPrimary | 大标题、品牌名称 |
| `headlineMedium` | 22 | w600 | textPrimary | 卡片组标题 |
| `titleLarge` | 17 | w600 | textPrimary | 列表项标题 |
| `bodyLarge` | 17 | w400 | textPrimary | 正文 |
| `bodyMedium` | 15 | w400 | textSecondary | 次要正文 |
| `bodySmall` | 13 | w400 | textSecondary | 辅助说明 |
| `labelLarge` | 15 | w500 | primaryColor | 按钮文字 |

### 使用示例

```dart
// 推荐方式：使用 IOS26Theme 静态访问器
Text('标题', style: IOS26Theme.titleLarge);
Text('正文内容', style: IOS26Theme.bodyLarge);
Text('提示信息', style: IOS26Theme.bodySmall);

// 间距使用
const SizedBox(height: IOS26Theme.spacingLg);
Padding(padding: const EdgeInsets.all(IOS26Theme.spacingMd));

// 圆角使用
BorderRadius.circular(IOS26Theme.radiusXl);
```

---

## 四、代码质量验证

- ✅ 无编译错误
- ✅ 所有 CircularProgressIndicator 已替换 (13处)
- ✅ 所有 IconButton 已替换 (7处)
- ✅ 所有 TextButton 已替换 (1处)
- ✅ 所有 InkWell 已替换 (1处)
- ✅ 所有 Material Icons 已替换 (3处)
- ✅ 所有 Divider 已替换 (1处)
- ✅ 主题扩展完整
- ✅ 所有图标统一为 CupertinoIcons

---

## 五、剩余 Material 组件说明

以下组件仍为 Material 组件，但属于 Flutter 框架限制或设计选择：

### 1. RefreshIndicator (3处)
**位置**:
- `overcooked_recipes_tab.dart`
- `overcooked_meal_tab.dart`
- `overcooked_wishlist_tab.dart`

**说明**: Flutter 的 Cupertino 包没有直接对应的下拉刷新组件。如需纯 iOS 风格，需要重构为 `CustomScrollView` + `CupertinoSliverRefreshControl`，这是一个较大的改动，建议后续版本考虑。

### 2. Scaffold、AppBar 等基础组件
**说明**: 这些组件在 Flutter 中是跨平台的，虽然属于 Material 包，但在 iOS 风格项目中广泛使用，且与 iOS 设计不冲突。

---

## 六、总结

通过本次深度优化，项目已建立完整的设计系统基础：

1. **组件层面**: 
   - 所有加载指示器统一为 iOS 风格的 CupertinoActivityIndicator
   - 所有按钮统一为 CupertinoButton
   - 所有图标统一为 CupertinoIcons
   - 移除所有 InkWell、Divider 等 Material 特有组件

2. **主题层面**: 
   - 提供了完整的文本样式规范 (11个样式)
   - 提供了间距规范 (7个级别)
   - 提供了圆角规范 (6个级别)

3. **代码层面**: 
   - 提供了便捷的静态访问器，便于业务代码使用
   - 所有修改保持向后兼容

项目现在拥有**纯 iOS 风格**的视觉体系，无 Material 组件残留（除 RefreshIndicator 和基础框架组件外），为后续开发和维护奠定了良好基础。
