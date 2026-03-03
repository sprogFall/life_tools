import '../../../core/ai/ai_call_source.dart';
import '../../../core/ai/ai_use_case.dart';
import '../xiao_mi_constants.dart';

class XiaoMiAiPrompts {
  XiaoMiAiPrompts._();

  static const String preRouteSystemPrompt = '''
你是“小蜜”聊天入口的预选路由器，需要先判断这条消息是否触发特殊调用。

可用特殊调用：
1) work_log_week_summary：用户要求“本周/这周工作总结、周报、周复盘”时触发。
2) work_log_month_summary：用户要求“本月工作总结、月报、月复盘”时触发。
3) work_log_quarter_summary：用户要求“本季度/Q1/Q2/Q3/Q4总结、季度复盘”时触发。
4) work_log_year_summary：用户要求“今年/年度工作总结、年终复盘”时触发。

可选 arguments：
- style: concise|review|risk|highlight|management（用于指定总结风格）
- date: YYYY-MM-DD（用于指定“某一周”）
- year: 年份整数（用于指定“某一年/某月/某季度”）
- month: 1-12（用于指定“某个月”）
- quarter: 1-4（用于指定“某个季度”）

参数规则：
1) 用户提到“今年一月份/2025年1月”这类明确月份时，必须使用 work_log_month_summary，并补充 year/month。
2) 用户提到“2025年Q2/第二季度”这类明确季度时，必须使用 work_log_quarter_summary，并补充 year/quarter。
3) 用户提到“2025年总结”这类明确年份时，必须使用 work_log_year_summary，并补充 year。

输出规则（必须严格遵守）：
1) 只输出一个 JSON 对象，不要任何额外文字。
2) 触发特殊调用时输出：
{"type":"special_call","call":"work_log_month_summary","arguments":{"year":2026,"month":1,"style":"review"}}
3) 不触发时输出：
{"type":"no_special_call"}
4) 禁止输出 Markdown 代码块。
''';

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

  static const AiUseCaseSpec preRouteUseCase = AiUseCaseSpec(
    id: 'xiao_mi_chat_pre_route',
    systemPrompt: preRouteSystemPrompt,
    inputLabel: '用户输入',
    temperature: 0.2,
    maxOutputTokens: 1200,
    timeout: Duration(seconds: 60),
    source: AiCallSource(
      toolId: XiaoMiConstants.toolId,
      toolName: XiaoMiConstants.toolName,
      featureId: 'chat_pre_route',
      featureName: '聊天预选',
    ),
  );

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
