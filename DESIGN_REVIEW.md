# 设计审查报告 (Design Review Report)

**日期**: 2026-01-29
**审查对象**: life_tools 项目 UI/UX
**审查目标**: 识别视觉不和谐、风格不统一问题，制定 iOS 26 风格统一化方案。

## 1. 总体评估 (Executive Summary)

项目整体代码质量较高，严格遵循了 iOS 26 的颜色规范。`IOS26Theme` 被广泛引用，硬编码颜色的情况极少（除了标准的黑白透明）。主要 UI 组件使用了 Cupertino 风格，符合设计预期。

然而，在排版（Typography）和部分组件细节上仍存在不一致。大量的文本样式（字体大小、粗细）散落在业务代码中，未统一引用主题配置。此外，仍有少量 Material Design 组件残留，影响了纯粹的 iOS 风格体验。

## 2. 问题清单 (Issues List)

### 2.1 排版样式不统一 (Typography Inconsistency) - **[高优先级]**
- **现象**: 业务代码中大量使用 `TextStyle(fontSize: 13/14/17, fontWeight: ...)`，手动指定字号和粗细。
- **影响**: 字体层级不清晰，一旦需要调整全局字体大小时，维护成本极高。
- **位置**: 几乎所有页面文件，例如 `tag_manager_tool_page.dart`, `stockpile_ai_batch_entry_page.dart` 等。

### 2.2 Material 组件残留 (Material Components Residue) - **[中优先级]**
- **现象**: 
    1. 存在 13 处 `CircularProgressIndicator` 使用。
    2. `lib/tools/overcooked_kitchen/pages/recipe/overcooked_recipe_edit_page.dart` 中使用了 `TextButton`。
- **影响**: 加载动画和按钮交互与 iOS 风格不符，破坏沉浸感。
- **建议**: 
    - `CircularProgressIndicator` -> `CupertinoActivityIndicator`
    - `TextButton` -> `CupertinoButton` (padding: zero)

### 2.3 自定义 AppBar 重复实现 (Custom AppBar Duplication) - **[低优先级]**
- **现象**: 部分主工具页面（如 `home_page.dart`）实现了私有的 AppBar 构建方法，虽然视觉上尽量模仿了 `IOS26AppBar`，但存在代码重复。
- **建议**: 评估是否可以直接复用 `IOS26AppBar`，或提取通用的 `SliverAppBar` 变体。

## 3. 改进建议与规范 (Improvement Plan & Guidelines)

### 3.1 建立文本样式系统
在 `IOS26Theme` 中完善 `TextTheme` 定义，并强制业务代码使用主题样式。

| 样式名称 | 字号 | 字重 | 颜色 | 用途 |
| :--- | :--- | :--- | :--- | :--- |
| `displayLarge` | 34 | w700 | Primary | 大标题 |
| `headlineMedium` | 22 | w600 | Primary | 页面标题 |
| `titleMedium` | 17 | w600 | Primary | 卡片/列表项标题 |
| `bodyLarge` | 17 | w400 | Primary | 正文 |
| `bodyMedium` | 15 | w400 | Secondary | 次要正文 |
| `bodySmall` | 13 | w400 | Secondary | 辅助说明 |
| `labelLarge` | 15 | w500 | ThemeColor | 按钮文字 |

**代码重构目标**:
```dart
// Before
Text('标题', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: IOS26Theme.textPrimary));

// After
Text('标题', style: Theme.of(context).textTheme.titleMedium);
// 或者使用 IOS26Theme 静态访问 (如果 Theme.of 较繁琐)
Text('标题', style: IOS26Theme.textStyle.titleMedium);
```

### 3.2 组件替换行动项
1. 全局搜索 `CircularProgressIndicator` 并替换为 `CupertinoActivityIndicator`。
2. 替换 `overcooked_recipe_edit_page.dart` 中的 `TextButton`。

## 4. 下一步行动 (Next Steps)

1.  **完善 Theme 定义**: 检查并扩充 `IOS26Theme` 中的文本样式定义，确保覆盖所有现有用例。
2.  **替换 Loading 组件**: 执行全局替换。
3.  **重构文本样式**: 分模块（Core, Tools）逐步替换硬编码的 `TextStyle`。
