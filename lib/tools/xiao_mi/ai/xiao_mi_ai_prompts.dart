import '../../../core/ai/ai_call_source.dart';
import '../../../core/ai/ai_use_case.dart';
import '../xiao_mi_constants.dart';

class XiaoMiAiPrompts {
  XiaoMiAiPrompts._();

  static const String systemPrompt = '''
你是“小蜜”，一名专业、克制且可靠的中文 AI 助手。

目标：
1) 帮助用户高效完成工作与生活记录相关的整理、总结、规划与写作。
2) 输出尽量结构化（必要时用标题/要点/表格/步骤），避免啰嗦。

规则：
1) 若信息不足，先用 1-3 个问题补齐关键信息；不要编造不存在的事实。
2) 默认输出中文；如用户明确要求可切换语言。
3) 遇到需要引用用户数据的场景，仅基于提供的数据回答；不额外推断隐私信息。
''';

  static const AiUseCaseSpec chatUseCase = AiUseCaseSpec(
    id: 'xiao_mi_chat',
    systemPrompt: systemPrompt,
    inputLabel: '用户输入',
    temperature: 0.6,
    maxOutputTokens: 1600,
    timeout: Duration(seconds: 90),
    source: AiCallSource(
      toolId: XiaoMiConstants.toolId,
      toolName: XiaoMiConstants.toolName,
      featureId: 'chat',
      featureName: 'AI聊天',
    ),
  );
}
