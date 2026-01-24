# 中文日期时间选择器示例

## 概述

应用已配置为使用中文显示所有 Flutter 内置的日期时间选择器组件。

## 使用示例

### CupertinoDatePicker（iOS风格日期选择器）

```dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void _showDatePicker(BuildContext context) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (context) {
      var selectedDate = DateTime.now();
      return Container(
        height: 300,
        color: Colors.white,
        child: Column(
          children: [
            // 顶部按钮栏
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),  // 自定义文本
                  ),
                  CupertinoButton(
                    onPressed: () {
                      // 处理选中的日期
                      Navigator.pop(context);
                    },
                    child: const Text('完成'),  // 自定义文本
                  ),
                ],
              ),
            ),
            // 日期选择器 - 会自动显示中文月份
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selectedDate,
                onDateTimeChanged: (value) {
                  selectedDate = value;
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
```

### 效果说明

配置后，CupertinoDatePicker 将自动显示：
- **中文月份**：一月、二月、三月... 十二月
- **中文日期格式**：X月X日
- **年份显示**：XXXX年

### 日期时间选择器

```dart
void _showDateTimePicker(BuildContext context) {
  showCupertinoModalPopup<void>(
    context: context,
    builder: (context) {
      var selectedDateTime = DateTime.now();
      return Container(
        height: 320,
        color: Colors.white,
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  CupertinoButton(
                    onPressed: () {
                      // 处理选中的日期时间
                      Navigator.pop(context);
                    },
                    child: const Text('完成'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.dateAndTime,
                initialDateTime: selectedDateTime,
                onDateTimeChanged: (value) {
                  selectedDateTime = value;
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
```

### 效果说明

日期时间选择器会显示：
- **日期部分**：中文格式（X月X日）
- **时间部分**：24小时制（如：14:30）

## 实际应用

在工作日志工具中的使用：

1. **工时记录页面** (`work_time_entry_edit_page.dart`)
   - 日期选择器显示中文月份
   - 用户体验更符合中文用户习惯

2. **任务编辑页面** (`work_task_edit_page.dart`)
   - 开始时间和结束时间选择器
   - 完整的中文日期时间显示

## 注意事项

1. **不需要额外代码**：配置在应用级别完成，所有使用 CupertinoDatePicker 的地方都会自动生效
2. **自定义格式不受影响**：应用中自定义的日期格式化逻辑（如 `_formatDate` 方法）保持不变
3. **兼容性**：支持中文（zh_CN）和英文（en_US）两种语言环境

## 测试

在测试中使用日期选择器时，请使用 `TestAppWrapper` 确保国际化配置正确：

```dart
import 'package:flutter_test/flutter_test.dart';

// TestAppWrapper 位于 test/test_helpers/test_app_wrapper.dart，请按需调整相对路径：
// - test/widget_test.dart: import 'test_helpers/test_app_wrapper.dart';
// - test/core/**: import '../../test_helpers/test_app_wrapper.dart';
import 'test_helpers/test_app_wrapper.dart';

testWidgets('日期选择器应显示中文', (tester) async {
  await tester.pumpWidget(
    TestAppWrapper(
      child: YourPageWithDatePicker(),
    ),
  );
  
  // 测试日期选择器...
});
```
