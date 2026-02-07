import '../../../core/ai/ai_use_case.dart';
import '../models/work_task.dart';
import '../models/work_time_entry.dart';

class WorkLogAiSummaryStyle {
  final String id;
  final String l10nKey;
  final String instruction;

  const WorkLogAiSummaryStyle({
    required this.id,
    required this.l10nKey,
    required this.instruction,
  });
}

class WorkLogAiSummaryPrompts {
  WorkLogAiSummaryPrompts._();

  static const AiUseCaseSpec summaryUseCase = AiUseCaseSpec(
    id: 'work_log_generate_summary',
    systemPrompt: systemPrompt,
    inputLabel: '工作记录',
    temperature: 0.2,
    maxOutputTokens: 1600,
    timeout: Duration(seconds: 60),
  );

  static const String systemPrompt = '''
你是一名专业的工作总结助手。
你的职责：基于提供的工时记录与工作内容，输出结构清晰、可直接复用的中文总结。

要求：
1) 严格基于输入数据，不虚构未出现的任务、里程碑或风险。
2) 语言精炼，先总后分，体现时间投入与工作产出。
3) 如信息不足，请明确指出“信息不足”的部分，不要臆测。
''';

  static const List<WorkLogAiSummaryStyle> styles = [
    WorkLogAiSummaryStyle(
      id: 'concise',
      l10nKey: 'work_log_ai_summary_style_concise',
      instruction: '生成精简周报风格：先给 3-5 条要点，再给“本期投入 / 主要产出 / 下一步”。',
    ),
    WorkLogAiSummaryStyle(
      id: 'review',
      l10nKey: 'work_log_ai_summary_style_review',
      instruction: '生成复盘风格：按“做了什么 -> 为什么 -> 效果如何 -> 经验”输出，强调因果关系。',
    ),
    WorkLogAiSummaryStyle(
      id: 'risk',
      l10nKey: 'work_log_ai_summary_style_risk',
      instruction: '生成风险导向风格：先写进展，再单列“风险/阻塞/依赖项”，并给可执行建议。',
    ),
    WorkLogAiSummaryStyle(
      id: 'highlight',
      l10nKey: 'work_log_ai_summary_style_highlight',
      instruction: '生成成果亮点风格：突出关键成果、关键投入与可量化价值，适合对外同步。',
    ),
    WorkLogAiSummaryStyle(
      id: 'management',
      l10nKey: 'work_log_ai_summary_style_management',
      instruction: '生成管理汇报风格：先总体工时与产出，再分任务简报，最后给出下阶段建议。',
    ),
  ];

  static WorkLogAiSummaryStyle defaultStyle() => styles.first;

  static WorkLogAiSummaryStyle resolveStyle(String id) {
    for (final style in styles) {
      if (style.id == id) return style;
    }
    return defaultStyle();
  }

  static String buildPrompt({
    required DateTime startDate,
    required DateTime endDate,
    required WorkLogAiSummaryStyle style,
    required List<WorkTask> selectedTasks,
    required List<String> selectedAffiliationNames,
    required List<WorkTimeEntry> filteredEntries,
    required Map<int, String> taskTitleById,
    required Map<int, List<String>> taskAffiliationNames,
  }) {
    final entries = [...filteredEntries]
      ..sort((a, b) {
        final date = a.workDate.compareTo(b.workDate);
        if (date != 0) return date;
        return a.createdAt.compareTo(b.createdAt);
      });

    final minutesByTask = <int, int>{};
    for (final entry in entries) {
      minutesByTask[entry.taskId] =
          (minutesByTask[entry.taskId] ?? 0) + entry.minutes;
    }

    final totalMinutes = entries.fold<int>(0, (sum, e) => sum + e.minutes);

    final selectedTaskText = selectedTasks
        .map((task) => '${task.id}:${task.title}')
        .join('；');

    final selectedAffiliationText = selectedAffiliationNames.isEmpty
        ? '全部归属'
        : selectedAffiliationNames.join('、');

    final taskSummary = minutesByTask.entries
        .map((entry) {
          final taskId = entry.key;
          final taskTitle = taskTitleById[taskId] ?? '任务#$taskId';
          final affiliations = taskAffiliationNames[taskId] ?? const [];
          final affiliationText = affiliations.isEmpty
              ? '未设置'
              : affiliations.join('/');
          return '- 任务：$taskTitle（ID=$taskId） | 归属：$affiliationText | 工时：${entry.value} 分钟';
        })
        .join('\n');

    final details = entries
        .take(320)
        .map((entry) {
          final taskTitle = taskTitleById[entry.taskId] ?? '任务#${entry.taskId}';
          final content = entry.content.trim().isEmpty
              ? '（无内容）'
              : entry.content;
          return '- 日期：${_formatDate(entry.workDate)} | 任务：$taskTitle | 工时：${entry.minutes} 分钟 | 内容：$content';
        })
        .join('\n');

    return '''
请根据以下工作记录生成中文总结。

【总结风格】
${style.instruction}

【输出格式要求】
1) 标题：给出一句总结标题。
2) 总览：2-4 句概述时间投入与核心成果。
3) 任务分解：按任务列出“投入工时 + 关键工作内容 + 结果”。
4) 建议：给出 2-3 条下一步建议（需与数据一致）。

【筛选条件】
时间范围：${_formatDate(startDate)} 至 ${_formatDate(endDate)}（含）
任务范围：$selectedTaskText
归属范围：$selectedAffiliationText

【统计摘要】
总记录数：${entries.length}
总工时：$totalMinutes 分钟
任务汇总：
$taskSummary

【工时明细】
$details
''';
  }

  static String _formatDate(DateTime dateTime) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}';
  }
}
