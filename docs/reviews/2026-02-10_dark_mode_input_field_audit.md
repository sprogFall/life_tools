# 2026-02-10 暗色模式输入框边界核查报告

## 背景

用户反馈在暗色模式下，多个输入框视觉上“融合在一起”，尤其在工作记录的「记录工时/编辑工时」页面中“内容”和“用时”分割不清晰。

本次治理目标：

1. 修复已出现的暗色模式输入框边界不清问题。
2. 建立代码级守护，杜绝后续新增同类问题。
3. 对关键页面执行一次人工核查并形成记录。

## 本次修复策略

1. 统一增强 `IOS26Theme.textFieldDecoration()` 暗色样式：
   - 提高暗色底色不透明度；
   - 提升边框 alpha 与线宽；
   - 增加轻阴影强化层级。
2. 将关键页面 `CupertinoTextField` 的 `decoration` 统一为 `IOS26Theme.textFieldDecoration(...)`。
3. 增加设计守护测试：
   - 禁止 `CupertinoTextField(decoration: null)`；
   - 关键页面强制使用 `IOS26Theme.textFieldDecoration(...)`。

## 人工核查清单（暗色模式）

核查环境：本地 Flutter 测试与代码走查；核查日期：2026-02-10。

### 1) 工作记录

- 页面：`WorkTimeEntryEditPage`（记录工时/编辑工时）
  - 核查点：内容输入框、用时输入框边界是否清晰
  - 结果：通过
- 页面：`WorkTaskEditPage`（任务编辑）
  - 核查点：标题/描述/预计工时输入框分隔
  - 结果：通过
- 页面：`WorkLogVoiceInputSheet`（AI录入）
  - 核查点：底部面板输入框边界与背景分离度
  - 结果：通过

### 2) 囤货助手

- 页面：`StockConsumptionEditPage`（记录消耗）
  - 核查点：消耗数量与备注输入框在暗色下边界清晰
  - 结果：通过
- 页面：`StockItemEditPage`（编辑物品）
  - 核查点：名称/数量/备注等输入框分隔
  - 结果：通过
- 组件：`StockpileBatchEntryTextField`
  - 核查点：批量录入字段边界与邻近控件分离
  - 结果：通过

### 3) 其他关键输入页

- 页面：`AiSettingsPage`
  - 结果：通过（已使用统一主题装饰）
- 页面：`SyncSettingsPage`
  - 结果：通过（已使用统一主题装饰）
- 页面：`ObjStoreSettingsPage`
  - 结果：通过（已统一改为主题装饰）
- 页面：`OvercookedRecipeEditPage`
  - 结果：通过（名称/简介/内容输入框已统一）
- 页面：`OvercookedMealTab`（评价弹窗）
  - 结果：通过（输入框已统一）
- 通用：`AppDialogs.showInput`
  - 结果：通过（输入框已统一）

## 防回归守护

新增或更新的守护：

1. `test/design/no_cupertino_text_field_null_decoration_in_pages_test.dart`
   - 扫描 `lib/**/*.dart`，禁止 `CupertinoTextField(decoration: null)`。
2. `test/design/cupertino_text_field_use_ios26_theme_decoration_test.dart`
   - 关键页面中 `CupertinoTextField` 强制使用 `IOS26Theme.textFieldDecoration(...)`。
3. `test/tools/work_log/work_time_entry_edit_page_layout_test.dart`
   - 新增暗色模式断言，确保工时页两个输入框均具备独立边框。

## 验证结论

- `flutter analyze`：通过
- `flutter test`：通过

结论：暗色模式输入框融合问题已修复，并通过设计守护将风险前移到测试阶段。
