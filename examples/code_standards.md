# 代码规范（代码审查沉淀）

## 异常处理

- 禁止空吞异常：不允许出现 `catch (_) {}`。至少使用 `devLog(...)` 记录（仅 Debug 输出），必要时给用户明确反馈（Dialog/Toast）。
- 日志脱敏：严禁在日志/异常信息中输出密钥/令牌/自定义 Header 等敏感信息；`devLog` 的 message/error 也必须遵守。

## 国际化（i18n）

- UI 文案禁止硬编码：页面标题、按钮文案、空态文案等必须使用 `AppLocalizations`（优先 `common_*`，模块内使用 `xxx_*` 命名）。
- 新增文案流程：同步更新 `lib/l10n/app_en.arb`、`lib/l10n/app_en_US.arb`、`lib/l10n/app_zh.arb`、`lib/l10n/app_zh_CN.arb`，并执行 `/opt/flutter/bin/flutter gen-l10n` 生成 Dart 文件。
- Widget 测试统一包裹：测试中优先使用 `test/test_helpers/test_app_wrapper.dart`，避免缺少 `localizationsDelegates` 导致页面崩溃。

## 规范守护（测试）

设计/规范类约束通过测试守护：

- `test/design/no_empty_catch_blocks_test.dart`
- `test/design/no_edge_insets_all_8_test.dart`
- `test/design/single_child_scroll_view_stretch_width_test.dart`
- `test/design/no_colors_white_test.dart`
- `test/design/no_direct_ios26_button_color_test.dart`
- `test/design/no_colored_cupertino_button_in_pages_test.dart`
- `test/design/no_direct_ios26_button_foreground_test.dart`
- `test/design/no_direct_icon_color_in_lib_test.dart`
- `test/design/no_raw_markdown_widgets_test.dart`
- `test/design/no_raw_image_constructors_test.dart`
