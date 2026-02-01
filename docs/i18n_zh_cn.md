# 国际化（i18n）与组件中文化说明

## 修改概述

本项目已启用 Flutter 国际化支持，并将应用默认 `locale` 设为 `zh_CN`，以确保公共组件（特别是日期时间选择器）默认使用中文显示。

## 修改内容

### 1. 主应用配置 (lib/main.dart)

在 `MaterialApp` 中添加/维护国际化配置（推荐通过 `AppLocalizations` 统一提供 delegates 与 supportedLocales）：

```dart
import 'l10n/app_localizations.dart';

// ...

MaterialApp(
  locale: const Locale('zh', 'CN'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  // ...
)
```

### 1.1 本地化资源（ARB）

本项目使用 ARB 存放文案资源：

- 目录：`lib/l10n/`
- 配置：`l10n.yaml`

为兼容 region locale（如 `en_US`/`zh_CN`）的 fallback 机制，同时提供 base locale（`en`/`zh`）与 region locale 的 ARB 文件。

### 2. 测试辅助工具 (test/test_helpers/test_app_wrapper.dart)

创建了 `TestAppWrapper` 类，为测试提供统一的国际化配置包装器（确保系统组件本地化可用）。

## 影响的组件

配置生效后，以下 Flutter 内置组件将自动显示为中文：

1. **CupertinoDatePicker** - iOS风格日期时间选择器
   - 月份名称显示为中文（一月、二月等）
   - 日期格式使用中文习惯
   - 时间显示使用24小时制

2. **日期时间选择对话框**
   - 所有系统对话框的按钮文本（确定、取消等）
   - 日期选择器的表头文本

3. **表单验证信息**
   - Flutter 内置的表单验证错误信息

## 使用位置

### 工作日历时间选择

- `lib/tools/work_log/pages/time/work_time_entry_edit_page.dart` (第259行)
  - 工时记录页面的日期选择器
  - 显示：中文月份名称 + 年月日格式

- `lib/tools/work_log/pages/task/work_task_edit_page.dart` (第343行)
  - 任务编辑页面的日期时间选择器
  - 显示：完整的中文日期时间格式

### 日历视图

- `lib/tools/work_log/pages/calendar/work_log_calendar_view.dart`
  - 已完全使用中文（周一至周日、月份等）
  - 本次修改不涉及此文件

## 测试

在编写测试时，请使用 `TestAppWrapper` 包装测试组件以确保国际化配置正确：

```dart
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/test_app_wrapper.dart';

testWidgets('测试示例', (tester) async {
  await tester.pumpWidget(
    TestAppWrapper(
      child: YourWidget(),
    ),
  );
  // 测试代码...
});
```

## 注意事项

1. 所有新建的测试文件都应该使用 `TestAppWrapper` 来包装被测试的组件
2. 自定义的日期格式化逻辑（如日历视图中的格式化）保持不变
3. i18n 基础设施已就绪，但业务中文文案的全量替换建议按模块渐进推进
