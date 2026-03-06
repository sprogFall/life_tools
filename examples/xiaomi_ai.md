# 小蜜 AI 功能扩展规范（预置提示词与接口）

本文档用于指导后续在小蜜工具中新增 AI 能力，统一预置提示词、特殊调用、路由编排与测试约束，避免实现分散和行为不一致。

---

## 1. 目标与范围

- 统一 AI 相关职责边界：提示词定义、预置注册、特殊调用解析、发送编排。
- 为后续新增功能提供固定扩展入口与命名规范。
- 降低新增功能时的改动面、回归风险与维护成本。

适用目录：

- `lib/tools/xiao_mi/ai/*`
- `lib/tools/xiao_mi/services/xiao_mi_chat_service.dart`
- `test/tools/xiao_mi/*`

---

## 2. 分层职责

### 2.1 `xiao_mi_ai_prompts.dart`

- 管理 AI 用例级 `systemPrompt` 与 `AiUseCaseSpec`。
- 管理模型调用参数（如 `temperature`、`maxOutputTokens`、`responseFormat`）。
- 不承载业务数据查询逻辑与预置词列表。

### 2.2 `xiao_mi_prompt_preset.dart`

- 统一注册预置提示词。
- 管理预置词展示文案、特殊调用 ID、静态参数。
- 作为 UI 空态与发送前本地命中的唯一来源。

### 2.3 `xiao_mi_prompt_resolver.dart`

- 负责把预置词/特殊调用解析为最终 `aiPrompt`。
- 负责时间范围推导、参数归一化、本地数据注入。
- 产出结构化 `metadata`（如 `triggerSource`、`queryStartDate`、`queryEndDate`）。

### 2.4 `xiao_mi_chat_service.dart`

- 负责发送链路编排。
- 固定顺序：先本地预置命中，再 AI 预选路由，最后正式对话。
- 不在 service 内新增分散规则；规则统一下沉到 resolver/registry。

---

## 3. 预置提示词数据模型

```dart
class XiaoMiQuickPrompt {
  final String id;
  final String text;
  final String description;
  final String? specialCallId;
  final Map<String, Object?> arguments;
}
```

字段约束：

- `id`：稳定唯一标识，不随展示文案变更而变化。
- `text`：默认展示文案；允许作为默认发送文案。
- `description`：用于说明用途，不参与解析。
- `specialCallId`：可空；非空表示可直接进入特殊调用。
- `arguments`：仅承载静态参数；动态参数（时间等）由 resolver 计算。

---

## 4. 统一接口规范

### 4.1 注册表接口

```dart
class XiaoMiPromptPresetRegistry {
  static const List<XiaoMiQuickPrompt> quickPrompts;
  static XiaoMiQuickPrompt? findById(String id);
  static XiaoMiQuickPrompt? matchByText(String text);
}
```

要求：

- `quickPrompts` 为 UI 唯一数据源。
- `matchByText(...)` 需做空白归一化与大小写归一化。
- 新增预置词只改注册表，不在页面和 service 中重复维护列表。

### 4.2 Resolver 接口

```dart
class XiaoMiPromptResolver {
  List<XiaoMiQuickPrompt> get quickPrompts;
  Future<XiaoMiResolvedPrompt?> resolveQuickPromptText(String rawText);
  Future<XiaoMiResolvedPrompt> resolveQuickPrompt(XiaoMiQuickPrompt prompt);
  Future<XiaoMiResolvedPrompt> resolveSpecialCall({
    required String callId,
    required String displayText,
    Map<String, Object?> arguments = const <String, Object?>{},
    String triggerSource = 'pre_route',
  });
}
```

要求：

- `resolveQuickPromptText(...)` 仅负责“文本 -> 预置命中 -> 解析结果”。
- `resolveSpecialCall(...)` 统一处理所有工具级特殊能力。
- `triggerSource` 必须保留，允许值：`preset`、`pre_route`。

### 4.3 ChatService 编排

```dart
Future<void> send(String rawText) async {
  // 1) 本地预置命中
  // 2) 未命中 -> AI 预选
  // 3) 正式 chatStream
}
```

要求：

- 本地可确定意图时，不再额外调用 AI 预选。
- AI 预选请求应显式使用 JSON 输出格式。
- 正式对话只消费最终 prompt，不感知来源细节。

---

## 5. 特殊调用规范

### 5.1 命名规范

统一使用：`<domain>_<action>` 或 `<domain>_<scope>_<action>`。

示例：

- `work_log_range_summary`
- `work_log_week_summary`
- `work_log_month_summary`
- `work_log_quarter_summary`
- `work_log_year_summary`
- `overcooked_context_query`

### 5.2 参数规范

- 字段命名使用 `snake_case`。
- 日期参数统一 `YYYYMMDD`。
- 相对时间必须在 resolver 中换算为绝对日期。
- 特殊调用参数以结构化字段为主，避免依赖自由文本二次猜测。

示例：

```json
{
  "type": "special_call",
  "call": "work_log_range_summary",
  "arguments": {
    "start_date": "20260101",
    "end_date": "20261231",
    "style": "management"
  }
}
```

---

## 6. 新增功能流程（强约束）

### 6.1 新增预置词

1. 在 `xiao_mi_prompt_preset.dart` 注册预置词。
2. 若需要特殊能力，配置 `specialCallId` 与静态 `arguments`。
3. 在 resolver 中补齐对应解析逻辑（时间、参数、数据注入）。
4. 在 service 中保持既有编排顺序，不新增旁路分支。
5. 更新本文档中相关规范（如新增调用协议）。

### 6.2 新增特殊调用

1. 在预选路由提示词中补充调用协议与参数规则。
2. 在 resolver 中新增 `callId` 分支，并输出统一 metadata。
3. 仅在 resolver 层访问数据仓库，不在 UI/service 层拼接上下文。
4. 对空数据、参数缺失、异常场景给出一致兜底策略。

---

## 7. 测试要求

新增或改动 AI 预置逻辑时，至少覆盖：

- 注册表测试：可按 id 查询，可按文本命中。
- resolver 测试：
  - 命中预置词后 `triggerSource == 'preset'`
  - 时间范围边界正确（周/月/季度/年）
  - 参数归一化与异常兜底正确
- service 测试：
  - 预置命中时跳过 AI 预选
  - 未命中时走 AI 预选
  - 预选调用使用 JSON 响应格式

---

## 8. 扩展建议

- 可扩展字段：`category`、`priority`、`sendText`（展示文案与发送文案分离）。
- 可扩展能力：预置词配置化加载（本地 JSON/远端下发）。
- 扩展时保持兼容：旧 `id` 不重命名，避免历史记录与埋点失效。

---

## 9. 实施检查清单

每次提交前自检：

- 是否仅在注册表维护预置词列表。
- 是否保持 service 编排顺序不变。
- 是否在 resolver 中收敛规则而非分散到页面。
- 是否补齐了最小测试覆盖。
- 是否更新了本文档对应规范。
