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
    final now = _normalizeDay(_nowProvider());
    final builder = XiaoMiWorkLogSummaryPromptBuilder(
      repository: _workLogRepository,
      nowProvider: _nowProvider,
    );

    switch (normalizedCallId) {
      case 'work_log_week_summary':
        final anchorDate =
            _resolveDate(arguments['date']) ??
            _resolveDate(arguments['anchor_date']) ??
            now;
        final prompt = await builder.buildWeekByAnchor(
          anchorDate: anchorDate,
          styleId: styleId,
        );
        if (prompt == null) {
          throw const XiaoMiNoWorkLogDataException('该周没有可用的工作记录，无法生成总结');
        }
        return _buildTriggeredPrompt(
          displayText: normalizedDisplayText,
          aiPrompt: prompt,
          presetId: workLogWeekSummary.id,
        );
      case 'work_log_month_summary':
        final month = _resolveMonth(arguments['month']);
        final year = _resolveYear(arguments['year']) ?? now.year;
        final prompt = month == null
            ? await builder.buildCurrentMonth(styleId: styleId)
            : await builder.buildMonth(
                year: year,
                month: month,
                styleId: styleId,
              );
        if (prompt == null) {
          throw const XiaoMiNoWorkLogDataException('该月份没有可用的工作记录，无法生成总结');
        }
        return _buildTriggeredPrompt(
          displayText: normalizedDisplayText,
          aiPrompt: prompt,
          presetId: workLogMonthSummary.id,
        );
      case 'work_log_quarter_summary':
        final quarter = _resolveQuarter(arguments['quarter']);
        final year = _resolveYear(arguments['year']) ?? now.year;
        final prompt = quarter == null
            ? await builder.buildCurrentQuarter(styleId: styleId)
            : await builder.buildQuarter(
                year: year,
                quarter: quarter,
                styleId: styleId,
              );
        if (prompt == null) {
          throw const XiaoMiNoWorkLogDataException('该季度没有可用的工作记录，无法生成总结');
        }
        return _buildTriggeredPrompt(
          displayText: normalizedDisplayText,
          aiPrompt: prompt,
          presetId: workLogQuarterSummary.id,
        );
      case 'work_log_year_summary':
        final year = _resolveYear(arguments['year']);
        final prompt = year == null
            ? await builder.buildCurrentYear(styleId: styleId)
            : await builder.buildYear(year: year, styleId: styleId);
        if (prompt == null) {
          throw const XiaoMiNoWorkLogDataException('该年份没有可用的工作记录，无法生成总结');
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

  static DateTime _normalizeDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  static DateTime? _resolveDate(Object? value) {
    if (value == null) return null;
    final parsed = DateTime.tryParse(value.toString().trim());
    if (parsed == null) return null;
    return _normalizeDay(parsed);
  }

  static int? _resolveYear(Object? value) {
    final parsed = _resolveInt(value);
    if (parsed == null || parsed < 1970 || parsed > 9999) return null;
    return parsed;
  }

  static int? _resolveMonth(Object? value) {
    final parsed = _resolveInt(value);
    if (parsed == null || parsed < 1 || parsed > 12) return null;
    return parsed;
  }

  static int? _resolveQuarter(Object? value) {
    final parsed = _resolveInt(value);
    if (parsed == null || parsed < 1 || parsed > 4) return null;
    return parsed;
  }

  static int? _resolveInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }
}
