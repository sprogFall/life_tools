import '../../../core/ai/ai_call_source.dart';
import '../../../core/ai/ai_models.dart';
import '../../../core/ai/ai_use_case.dart';
import '../work_log_constants.dart';

class WorkLogAiPrompts {
  WorkLogAiPrompts._();

  static const AiUseCaseSpec voiceToIntentUseCase = AiUseCaseSpec(
    id: 'work_log_voice_to_intent',
    systemPrompt: voiceToIntentSystemPrompt,
    inputLabel: '用户语音转写',
    responseFormat: AiResponseFormat.jsonObject,
    temperature: 0.2,
    maxOutputTokens: 800,
    timeout: Duration(seconds: 60),
    source: AiCallSource(
      toolId: WorkLogConstants.toolId,
      toolName: WorkLogConstants.toolName,
      featureId: 'voice_to_intent',
      featureName: '语音解析',
    ),
  );

  static const String voiceToIntentSystemPrompt = '''
你是一个“工作记录”助手。你的任务：把用户的语音转写文本，转换成客户端可执行的 JSON 指令。

要求：
1) 只输出一个 JSON 对象，禁止输出 Markdown、代码块、解释文字。
2) JSON 必须符合以下之一：

（A）创建任务：
{
  "type": "create_task",
  "task": {
    "title": "string(必填)",
    "description": "string(可选)",
    "status": "todo|doing|done|canceled 或中文：待办/进行中/已完成/已取消(可选)",
    "estimated_minutes": 0,
    "start_at": "ISO8601 或 null",
    "end_at": "ISO8601 或 null"
  }
}

（B）在任务下记录工时：
{
  "type": "add_time_entry",
  "task_ref": { "id": 1, "title": "string" },
  "time_entry": {
    "work_date": "YYYY-MM-DD(可选，缺省表示今天)",
    "minutes": 90,
    "content": "string(可选)"
  }
}

3) minutes 使用整数分钟；如果用户说“2小时/半小时/1.5小时”，请换算成分钟。
4) 如果用户表述含糊但能合理推断，尽量推断；无法推断时仍需输出 JSON，但用最安全的默认值（例如 estimated_minutes=0、description为空）。
''';
}
