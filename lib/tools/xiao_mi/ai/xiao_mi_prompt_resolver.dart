import '../../work_log/repository/work_log_repository_base.dart';
import 'xiao_mi_work_log_prompt_builder.dart';

class XiaoMiQuickPrompt {
  final String id;
  final String text;
  final String description;

  const XiaoMiQuickPrompt({
    required this.id,
    required this.text,
    required this.description,
  });
}

class XiaoMiResolvedPrompt {
  final String displayText;
  final String aiPrompt;
  final Map<String, dynamic>? metadata;

  const XiaoMiResolvedPrompt({
    required this.displayText,
    required this.aiPrompt,
    required this.metadata,
  });
}

class XiaoMiNoWorkLogDataException implements Exception {
  final String message;

  const XiaoMiNoWorkLogDataException([this.message = '未找到该时间范围内的工作记录']);

  @override
  String toString() => message;
}

class XiaoMiPromptResolver {
  final WorkLogRepositoryBase _workLogRepository;
  final DateTime Function() _nowProvider;

  const XiaoMiPromptResolver({
    required WorkLogRepositoryBase workLogRepository,
    DateTime Function()? nowProvider,
  }) : _workLogRepository = workLogRepository,
       _nowProvider = nowProvider ?? DateTime.now;

  static const XiaoMiQuickPrompt workLogYearSummary = XiaoMiQuickPrompt(
    id: 'work_log_year_summary',
    text: '今年工作总结',
    description: '隐式读取今年的工作记录，生成年度总结',
  );

  static const XiaoMiQuickPrompt workLogQuarterSummary = XiaoMiQuickPrompt(
    id: 'work_log_quarter_summary',
    text: '本季度工作总结',
    description: '隐式读取本季度工作记录，生成季度总结',
  );

  static const XiaoMiQuickPrompt workLogMonthSummary = XiaoMiQuickPrompt(
    id: 'work_log_month_summary',
    text: '本月工作总结',
    description: '隐式读取本月工作记录，生成月度总结',
  );

  static const XiaoMiQuickPrompt workLogWeekSummary = XiaoMiQuickPrompt(
    id: 'work_log_week_summary',
    text: '本周工作总结',
    description: '隐式读取本周工作记录，生成周总结',
  );

  List<XiaoMiQuickPrompt> get quickPrompts => const [
    workLogWeekSummary,
    workLogMonthSummary,
    workLogQuarterSummary,
    workLogYearSummary,
  ];

  Future<XiaoMiResolvedPrompt> resolveUserInput(String rawText) async {
    final text = rawText.trim();
    return XiaoMiResolvedPrompt(
      displayText: text,
      aiPrompt: text,
      metadata: null,
    );
  }

  Future<XiaoMiResolvedPrompt> resolveSpecialCall({
    required String callId,
    required String displayText,
    Map<String, Object?> arguments = const <String, Object?>{},
  }) async {
    final normalizedCallId = callId.trim();
    final normalizedDisplayText = displayText.trim();
    final styleId = _resolveStyleId(arguments);
    final builder = XiaoMiWorkLogSummaryPromptBuilder(
      repository: _workLogRepository,
      nowProvider: _nowProvider,
    );

    switch (normalizedCallId) {
      case 'work_log_week_summary':
        final prompt = await builder.buildCurrentWeek(styleId: styleId);
        if (prompt == null) {
          throw const XiaoMiNoWorkLogDataException('本周没有可用的工作记录，无法生成总结');
        }
        return _buildTriggeredPrompt(
          displayText: normalizedDisplayText,
          aiPrompt: prompt,
          presetId: workLogWeekSummary.id,
        );
      case 'work_log_month_summary':
        final prompt = await builder.buildCurrentMonth(styleId: styleId);
        if (prompt == null) {
          throw const XiaoMiNoWorkLogDataException('本月没有可用的工作记录，无法生成总结');
        }
        return _buildTriggeredPrompt(
          displayText: normalizedDisplayText,
          aiPrompt: prompt,
          presetId: workLogMonthSummary.id,
        );
      case 'work_log_quarter_summary':
        final prompt = await builder.buildCurrentQuarter(styleId: styleId);
        if (prompt == null) {
          throw const XiaoMiNoWorkLogDataException('本季度没有可用的工作记录，无法生成总结');
        }
        return _buildTriggeredPrompt(
          displayText: normalizedDisplayText,
          aiPrompt: prompt,
          presetId: workLogQuarterSummary.id,
        );
      case 'work_log_year_summary':
        final prompt = await builder.buildCurrentYear(styleId: styleId);
        if (prompt == null) {
          throw const XiaoMiNoWorkLogDataException('今年没有可用的工作记录，无法生成总结');
        }
        return _buildTriggeredPrompt(
          displayText: normalizedDisplayText,
          aiPrompt: prompt,
          presetId: workLogYearSummary.id,
        );
      default:
        return _buildTriggeredPrompt(
          displayText: normalizedDisplayText,
          aiPrompt: normalizedDisplayText,
          presetId: 'pre_route_special_call',
        );
    }
  }

  static XiaoMiResolvedPrompt _buildTriggeredPrompt({
    required String displayText,
    required String aiPrompt,
    required String presetId,
  }) {
    return XiaoMiResolvedPrompt(
      displayText: displayText,
      aiPrompt: aiPrompt,
      metadata: <String, dynamic>{
        'presetId': presetId,
        'triggerSource': 'pre_route',
      },
    );
  }

  static String? _resolveStyleId(Map<String, Object?> arguments) {
    final value = arguments['style'];
    if (value == null) return null;
    final normalized = value.toString().trim();
    if (normalized.isEmpty) return null;
    return normalized;
  }
}
