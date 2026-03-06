class XiaoMiQuickPrompt {
  final String id;
  final String text;
  final String description;
  final String? specialCallId;
  final Map<String, Object?> arguments;

  const XiaoMiQuickPrompt({
    required this.id,
    required this.text,
    required this.description,
    this.specialCallId,
    this.arguments = const <String, Object?>{},
  });

  bool get hasSpecialCall {
    final callId = specialCallId?.trim();
    return callId != null && callId.isNotEmpty;
  }
}

class XiaoMiPromptPresetRegistry {
  XiaoMiPromptPresetRegistry._();

  static const XiaoMiQuickPrompt workLogYearSummary = XiaoMiQuickPrompt(
    id: 'work_log_year_summary',
    text: '今年工作总结',
    description: '隐式读取今年的工作记录，生成年度总结',
    specialCallId: 'work_log_year_summary',
  );

  static const XiaoMiQuickPrompt workLogQuarterSummary = XiaoMiQuickPrompt(
    id: 'work_log_quarter_summary',
    text: '本季度工作总结',
    description: '隐式读取本季度工作记录，生成季度总结',
    specialCallId: 'work_log_quarter_summary',
  );

  static const XiaoMiQuickPrompt workLogMonthSummary = XiaoMiQuickPrompt(
    id: 'work_log_month_summary',
    text: '本月工作总结',
    description: '隐式读取本月工作记录，生成月度总结',
    specialCallId: 'work_log_month_summary',
  );

  static const XiaoMiQuickPrompt workLogWeekSummary = XiaoMiQuickPrompt(
    id: 'work_log_week_summary',
    text: '本周工作总结',
    description: '隐式读取本周工作记录，生成周总结',
    specialCallId: 'work_log_week_summary',
  );

  static const List<XiaoMiQuickPrompt> quickPrompts = <XiaoMiQuickPrompt>[
    workLogWeekSummary,
    workLogMonthSummary,
    workLogQuarterSummary,
    workLogYearSummary,
  ];

  static XiaoMiQuickPrompt? findById(String id) {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) return null;
    for (final prompt in quickPrompts) {
      if (prompt.id == normalizedId) return prompt;
    }
    return null;
  }

  static XiaoMiQuickPrompt? matchByText(String text) {
    final normalizedText = _normalize(text);
    if (normalizedText.isEmpty) return null;
    for (final prompt in quickPrompts) {
      if (_normalize(prompt.text) == normalizedText) {
        return prompt;
      }
    }
    return null;
  }

  static String _normalize(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }
}
