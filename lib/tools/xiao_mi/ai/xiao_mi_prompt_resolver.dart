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
      case 'work_log_range_summary':
        final dateRange = _resolveDateRange(
          arguments: arguments,
          displayText: normalizedDisplayText,
          now: now,
        );
        final prompt = await builder.buildDateRange(
          start: dateRange.start,
          endInclusive: dateRange.endInclusive,
          styleId: styleId,
        );
        if (prompt == null) {
          throw const XiaoMiNoWorkLogDataException('该时间范围没有可用的工作记录，无法生成总结');
        }
        return _buildTriggeredPrompt(
          displayText: normalizedDisplayText,
          aiPrompt: prompt,
          presetId: _resolveRangePresetId(
            displayText: normalizedDisplayText,
            dateRange: dateRange,
          ),
        );
      case 'work_log_week_summary':
        final preferCurrentWeek = _isCurrentWeekRequest(normalizedDisplayText);
        final anchorDate = preferCurrentWeek
            ? now
            : (_resolveDate(arguments['date']) ??
                  _resolveDate(arguments['anchor_date']) ??
                  now);
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
        final preferCurrentMonth = _isCurrentMonthRequest(
          normalizedDisplayText,
        );
        final month = _resolveMonth(arguments['month']);
        final year = preferCurrentMonth
            ? now.year
            : (_resolveYear(arguments['year']) ?? now.year);
        final prompt = month == null || preferCurrentMonth
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
        final preferCurrentQuarter = _isCurrentQuarterRequest(
          normalizedDisplayText,
        );
        final quarter = _resolveQuarter(arguments['quarter']);
        final year = preferCurrentQuarter
            ? now.year
            : (_resolveYear(arguments['year']) ?? now.year);
        final prompt = quarter == null || preferCurrentQuarter
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
        final year = _isCurrentYearRequest(normalizedDisplayText)
            ? null
            : _resolveYear(arguments['year']);
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
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    final compact = _resolveCompactDate(raw);
    if (compact != null) return compact;
    final parsed =
        DateTime.tryParse(raw) ?? DateTime.tryParse(raw.replaceAll('/', '-'));
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

  static DateTime? _resolveCompactDate(String raw) {
    final match = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(raw);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) return null;
    if (year < 1970 || year > 9999 || month < 1 || month > 12) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  static _DateRange _resolveDateRange({
    required Map<String, Object?> arguments,
    required String displayText,
    required DateTime now,
  }) {
    final start =
        _resolveDate(arguments['start_date']) ??
        _resolveDate(arguments['startDate']) ??
        _resolveDate(arguments['start']) ??
        _resolveDate(arguments['from']) ??
        _resolveDate(arguments['from_date']);
    final end =
        _resolveDate(arguments['end_date']) ??
        _resolveDate(arguments['endDate']) ??
        _resolveDate(arguments['end']) ??
        _resolveDate(arguments['to']) ??
        _resolveDate(arguments['to_date']);

    if (start != null && end != null) {
      return _DateRange.normalize(start: start, endInclusive: end);
    }

    final fallback = _resolveDateRangeByDisplayText(
      displayText: displayText,
      now: now,
    );
    if (fallback != null) return fallback;
    throw const XiaoMiNoWorkLogDataException('未提供有效的时间范围，无法生成总结');
  }

  static _DateRange? _resolveDateRangeByDisplayText({
    required String displayText,
    required DateTime now,
  }) {
    if (_isCurrentYearRequest(displayText)) {
      return _DateRange(
        start: DateTime(now.year, 1, 1),
        endInclusive: DateTime(now.year, 12, 31),
      );
    }
    if (_isCurrentQuarterRequest(displayText)) {
      final quarter = ((now.month - 1) ~/ 3) + 1;
      final startMonth = (quarter - 1) * 3 + 1;
      return _DateRange(
        start: DateTime(now.year, startMonth, 1),
        endInclusive: DateTime(now.year, startMonth + 3, 0),
      );
    }
    if (_isCurrentMonthRequest(displayText)) {
      return _DateRange(
        start: DateTime(now.year, now.month, 1),
        endInclusive: DateTime(now.year, now.month + 1, 0),
      );
    }
    if (_isCurrentWeekRequest(displayText)) {
      final start = now.subtract(Duration(days: now.weekday - DateTime.monday));
      return _DateRange(
        start: start,
        endInclusive: start.add(const Duration(days: 6)),
      );
    }
    return null;
  }

  static String _resolveRangePresetId({
    required String displayText,
    required _DateRange dateRange,
  }) {
    if (_isCurrentWeekRequest(displayText) || _isWeekRange(dateRange)) {
      return workLogWeekSummary.id;
    }
    if (_isCurrentMonthRequest(displayText) || _isMonthRange(dateRange)) {
      return workLogMonthSummary.id;
    }
    if (_isCurrentQuarterRequest(displayText) || _isQuarterRange(dateRange)) {
      return workLogQuarterSummary.id;
    }
    if (_isCurrentYearRequest(displayText) || _isYearRange(dateRange)) {
      return workLogYearSummary.id;
    }
    return 'work_log_range_summary';
  }

  static bool _isYearRange(_DateRange dateRange) {
    final start = dateRange.start;
    final end = dateRange.endInclusive;
    return start.year == end.year &&
        start.month == 1 &&
        start.day == 1 &&
        end.month == 12 &&
        end.day == 31;
  }

  static bool _isQuarterRange(_DateRange dateRange) {
    final start = dateRange.start;
    final end = dateRange.endInclusive;
    if (start.day != 1) return false;
    if (start.month != 1 &&
        start.month != 4 &&
        start.month != 7 &&
        start.month != 10) {
      return false;
    }
    final expectedEnd = DateTime(start.year, start.month + 3, 0);
    return end.year == expectedEnd.year &&
        end.month == expectedEnd.month &&
        end.day == expectedEnd.day;
  }

  static bool _isMonthRange(_DateRange dateRange) {
    final start = dateRange.start;
    final end = dateRange.endInclusive;
    if (start.day != 1) return false;
    final expectedEnd = DateTime(start.year, start.month + 1, 0);
    return end.year == expectedEnd.year &&
        end.month == expectedEnd.month &&
        end.day == expectedEnd.day;
  }

  static bool _isWeekRange(_DateRange dateRange) {
    final start = dateRange.start;
    final end = dateRange.endInclusive;
    return start.weekday == DateTime.monday &&
        end.weekday == DateTime.sunday &&
        end.difference(start).inDays == 6;
  }

  static bool _isCurrentYearRequest(String text) {
    final normalized = _normalizeText(text);
    final hasCurrentYearKeyword =
        normalized.contains('今年') ||
        normalized.contains('本年') ||
        normalized.contains('本年度') ||
        normalized.contains('今年度');
    if (!hasCurrentYearKeyword) return false;
    return !RegExp(r'(19|20)\d{2}年').hasMatch(normalized);
  }

  static bool _isCurrentQuarterRequest(String text) {
    final normalized = _normalizeText(text);
    final hasCurrentQuarterKeyword =
        normalized.contains('本季度') ||
        normalized.contains('这季度') ||
        normalized.contains('本季') ||
        normalized.contains('当季') ||
        normalized.contains('当季度');
    if (!hasCurrentQuarterKeyword) return false;
    return !RegExp(
      r'((19|20)\d{2}年)?(q[1-4]|第?[一二三四1-4]季度)',
    ).hasMatch(normalized);
  }

  static bool _isCurrentMonthRequest(String text) {
    final normalized = _normalizeText(text);
    final hasCurrentMonthKeyword =
        normalized.contains('本月') ||
        normalized.contains('这个月') ||
        normalized.contains('这月') ||
        normalized.contains('当月');
    if (!hasCurrentMonthKeyword) return false;
    return !RegExp(r'((19|20)\d{2}年)?(1[0-2]|0?[1-9])月').hasMatch(normalized);
  }

  static bool _isCurrentWeekRequest(String text) {
    final normalized = _normalizeText(text);
    return normalized.contains('本周') ||
        normalized.contains('这周') ||
        normalized.contains('本星期') ||
        normalized.contains('这星期') ||
        normalized.contains('本礼拜') ||
        normalized.contains('这礼拜');
  }

  static String _normalizeText(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').toLowerCase();
  }
}

class _DateRange {
  final DateTime start;
  final DateTime endInclusive;

  const _DateRange({required this.start, required this.endInclusive});

  factory _DateRange.normalize({
    required DateTime start,
    required DateTime endInclusive,
  }) {
    if (endInclusive.isBefore(start)) {
      return _DateRange(start: endInclusive, endInclusive: start);
    }
    return _DateRange(start: start, endInclusive: endInclusive);
  }
}
