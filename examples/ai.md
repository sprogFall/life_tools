# AI 调用示例（OpenAI 兼容）

本项目已在 `lib/main.dart` 通过 Provider 全局注入 `AiService`，业务侧（页面/工具/服务）只需要通过 `context.read<AiService>()` 获取即可。

## 1) 单次 prompt -> 文本

```dart
import 'package:provider/provider.dart';
import 'package:life_tools/core/ai/ai_service.dart';

final ai = context.read<AiService>();

final text = await ai.chatText(
  prompt: '你好，请用一句话总结下面内容：...',
  systemPrompt: '你是一个严谨的助手',
);
```

## 2) 让 AI 严格输出 JSON（业务侧解析）

```dart
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:life_tools/core/ai/ai_models.dart';

final ai = context.read<AiService>();

final jsonText = await ai.chatText(
  prompt: '请只输出一个 JSON，形如 {"result":"..."}',
  responseFormat: AiResponseFormat.jsonObject,
);

final obj = jsonDecode(jsonText) as Map<String, dynamic>;
final result = obj['result'] as String?;
```

## 3) 多轮消息（自定义 role / history）

```dart
import 'package:provider/provider.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:life_tools/core/ai/ai_models.dart';

final ai = context.read<AiService>();

final reply = await ai.chat(
  messages: const [
    AiMessage.system('你是一个助手'),
    AiMessage.user('你好'),
    AiMessage.assistant('你好！'),
    AiMessage.user('请告诉我你是什么模型'),
  ],
);

print(reply.text);
```

## 4) 异常处理（建议业务侧兜底提示）

```dart
import 'package:provider/provider.dart';
import 'package:life_tools/core/ai/ai_service.dart';
import 'package:life_tools/core/ai/ai_errors.dart';

final ai = context.read<AiService>();

try {
  final text = await ai.chatText(prompt: '你好');
  // TODO: 使用 text 做后续业务逻辑
} on AiNotConfiguredException {
  // TODO: 提示用户先到设置里配置 AI
} on AiApiException catch (e) {
  // TODO: 提示调用失败，可展示 e.statusCode / e.message
}
```

