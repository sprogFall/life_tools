# AI 调用与治理规范（OpenAI 兼容）

本项目已在 `lib/main.dart` 通过 Provider 全局注入 `AiService`，业务侧（页面/工具/服务）通过 `context.read<AiService>()` 获取。

为了解决“提示词分散、参数重复、解析逻辑重复”的问题，AI 代码统一采用 **UseCase + Prompt + Context + IntentParser** 模式。

---

## 1) 统一分层（推荐目录）

- 核心层（跨工具复用）
  - `lib/core/ai/ai_service.dart`：底层 AI 调用入口
  - `lib/core/ai/ai_use_case.dart`：AI 用例规范（`AiUseCaseSpec` / `AiUseCaseExecutor` / `AiPromptComposer`）
  - `lib/core/ai/ai_json_utils.dart`：AI JSON 解析公共工具（提取 JSON、类型转换、日期解析）

- 工具层（各业务自定义）
  - `lib/tools/<tool>/ai/*_ai_prompts.dart`：集中管理系统提示词与用例参数
  - `lib/tools/<tool>/ai/*_ai_context.dart`：集中管理上下文拼装
  - `lib/tools/<tool>/ai/*_ai_assistant.dart`：仅负责编排调用，不堆业务细节
  - `lib/tools/<tool>/ai/*_ai_intent.dart`：把 AI JSON 解析成强类型 Intent

---

## 2) 用例定义：提示词与参数放在一起

不要在页面里散落 `temperature/maxOutputTokens/systemPrompt`，统一收敛到 `AiUseCaseSpec`。

```dart
// lib/tools/work_log/ai/work_log_ai_prompts.dart
static const AiUseCaseSpec voiceToIntentUseCase = AiUseCaseSpec(
  id: 'work_log_voice_to_intent',
  systemPrompt: voiceToIntentSystemPrompt,
  inputLabel: '用户语音转写',
  responseFormat: AiResponseFormat.jsonObject,
  temperature: 0.2,
  maxOutputTokens: 800,
  timeout: Duration(seconds: 60),
);
```

建议：
- `id` 使用稳定标识（便于后续埋点/排查）
- `systemPrompt` 只放角色和规则，不放运行时上下文
- 输入标签（`inputLabel`）语义清晰，如“用户输入”“用户语音转写”

---

## 3) 助手层：统一通过 Executor 调用

```dart
class DefaultWorkLogAiAssistant implements WorkLogAiAssistant {
  final AiUseCaseExecutor _executor;

  DefaultWorkLogAiAssistant({required AiService aiService})
    : _executor = AiUseCaseExecutor(aiService: aiService);

  @override
  Future<String> voiceTextToIntentJson({
    required String voiceText,
    required String context,
  }) {
    return _executor.run(
      spec: WorkLogAiPrompts.voiceToIntentUseCase,
      userInput: voiceText,
      context: context,
    );
  }
}
```

- `run(...)`：适合“上下文 + 用户输入”场景（会自动拼装 prompt）
- `runWithPrompt(...)`：适合你已经构建好完整 prompt 的场景（如 AI 总结页）

---

## 4) 上下文构建：单独函数，避免页面拼字符串

```dart
String buildWorkLogAiContext({
  required DateTime now,
  required Iterable<WorkTask> tasks,
}) {
  // 统一格式，便于模型稳定理解
}
```

原则：
- 仅放 AI 需要的信息，避免泄露无关/敏感内容
- 格式稳定（日期格式、列表格式固定）
- 做数量上限（如最多 60 条任务）

---

## 5) JSON 解析：统一使用 AiJsonUtils

意图解析器内，优先使用：
- `AiJsonUtils.decodeFirstObject(text)`：兼容前后缀噪声
- `AiJsonUtils.asMap/asList/asInt/asDouble/asString(...)`
- `AiJsonUtils.parseDateOnly/parseDateTime(...)`

这样可以避免每个模块重复实现 `_asMap/_asInt/_tryDecodeObject`。

---

## 6) 页面层职责（保持轻）

页面只做：
1. 收集输入
2. 调 assistant
3. 把 AI 返回交给 intent parser
4. 根据 intent 跳转到对应表单页/执行动作

不要在页面里：
- 写大段 system prompt
- 重复设置模型参数
- 直接手写 JSON 解析细节

---

## 7) 异常处理建议

```dart
try {
  final text = await ai.chatText(prompt: '你好');
} on AiNotConfiguredException {
  // 提示用户先完成 AI 配置
} on AiApiException catch (e) {
  // 展示状态码/错误消息（注意脱敏）
}
```

- 严禁空吞异常
- 日志不要输出密钥/Token/敏感 Header

---

## 8) 测试规范（TDD）

新增 AI 功能时，至少覆盖：
- `AiUseCase`：prompt 拼装、参数透传
- `ContextBuilder`：上下文格式与边界（空数据/上限）
- `IntentParser`：正常 JSON、缺字段、类型错误、带噪声 JSON
- 页面流程：按钮 -> 调用 AI -> 打开预填页面

参考测试：
- `test/core/ai/ai_use_case_test.dart`
- `test/core/ai/ai_json_utils_test.dart`
- `test/tools/work_log/work_log_ai_context_test.dart`
- `test/tools/work_log/work_log_ai_intent_test.dart`
- `test/tools/stockpile_assistant/stockpile_ai_intent_test.dart`

---

## 9) 旧代码迁移清单

当你接手已有 AI 页面，按以下顺序改造：
1. 抽取系统提示词到 `*_ai_prompts.dart`
2. 抽取上下文拼装到 `*_ai_context.dart`
3. 用 `AiUseCaseExecutor` 替换散落的 `chatText(...)`
4. 用 `AiJsonUtils` 收敛重复解析逻辑
5. 补齐测试并通过 `flutter analyze` / `flutter test`

这套规范的目标是：**提示词可管理、参数可复用、解析可维护、页面更薄、测试更稳**。
