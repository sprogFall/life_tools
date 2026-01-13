# 组件中文化说明

## 修改概述

本次修改将应用的公共组件（特别是日期时间选择器）配置为使用中文显示。

## 修改内容

### 1. 主应用配置 (lib/main.dart)

在 `MaterialApp` 中添加了国际化配置：

```dart
import 'package:flutter_localizations/flutter_localizations.dart';

// ...

MaterialApp(
  locale: const Locale('zh', 'CN'),
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [
    Locale('zh', 'CN'),
    Locale('en', 'US'),
  ],
  // ...
)
```

### 2. 测试辅助工具 (test/test_helpers/test_app_wrapper.dart)

创建了 `TestAppWrapper` 类，为测试提供统一的国际化配置包装器。

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
3. 该配置不影响应用内自定义的中文文本（如按钮标签、标题等）
