import '../../work_log/ai/work_log_ai_summary_prompts.dart';
import '../../work_log/repository/work_log_repository_base.dart';
import '../../../core/tags/tag_repository.dart';
import '../../work_log/models/work_task.dart';
import '../../work_log/models/work_time_entry.dart';

const List<String> _defaultQueryFields = <String>[
  'work_date',
  'task_title',
  'task_status',
  'affiliations',
  'minutes',
  'content',
];

class XiaoMiWorkLogSummaryPromptBuilder {
  final WorkLogRepositoryBase _repository;
  final TagRepository? _tagRepository;
  final DateTime Function() _nowProvider;

  const XiaoMiWorkLogSummaryPromptBuilder({
    required WorkLogRepositoryBase repository,
    TagRepository? tagRepository,
    DateTime Function()? nowProvider,
  }) : _repository = repository,
       _tagRepository = tagRepository,
       _nowProvider = nowProvider ?? DateTime.now;

  Future<String?> buildCurrentWeek({String? styleId}) {
    final today = _normalizeDay(_nowProvider());
    return buildWeekByAnchor(anchorDate: today, styleId: styleId);
  }

  Future<String?> buildCurrentMonth({String? styleId}) {
    final today = _normalizeDay(_nowProvider());
    return buildMonth(year: today.year, month: today.month, styleId: styleId);
  }

  Future<String?> buildCurrentQuarter({String? styleId}) {
    final today = _normalizeDay(_nowProvider());
    final quarter = ((today.month - 1) ~/ 3) + 1;
    return buildQuarter(year: today.year, quarter: quarter, styleId: styleId);
  }

  Future<String?> buildCurrentYear({String? styleId}) {
    final today = _normalizeDay(_nowProvider());
    return buildYear(year: today.year, styleId: styleId);
  }

  Future<String?> buildWeekByAnchor({
    required DateTime anchorDate,
    String? styleId,
  }) {
    final day = _normalizeDay(anchorDate);
    final start = day.subtract(Duration(days: day.weekday - DateTime.monday));
    final endInclusive = start.add(const Duration(days: 6));
    return _buildRange(
      start: start,
      endInclusive: endInclusive,
      style: _resolveStyle(
        preferredStyleId: styleId,
        fallbackStyleId: 'concise',
      ),
    );
  }

  Future<String?> buildMonth({
    required int year,
    required int month,
    String? styleId,
  }) {
    final start = DateTime(year, month, 1);
    final endInclusive = DateTime(year, month + 1, 0);
    return _buildRange(
      start: start,
      endInclusive: endInclusive,
      style: _resolveStyle(
        preferredStyleId: styleId,
        fallbackStyleId: 'review',
      ),
    );
  }

  Future<String?> buildQuarter({
    required int year,
    required int quarter,
    String? styleId,
  }) {
    final quarterStartMonth = (quarter - 1) * 3 + 1;
    final start = DateTime(year, quarterStartMonth, 1);
    final endInclusive = DateTime(year, quarterStartMonth + 3, 0);
    return _buildRange(
      start: start,
      endInclusive: endInclusive,
      style: _resolveStyle(
        preferredStyleId: styleId,
        fallbackStyleId: 'management',
      ),
    );
  }

  Future<String?> buildYear({required int year, String? styleId}) {
    final start = DateTime(year, 1, 1);
    final endInclusive = DateTime(year, 12, 31);
    return _buildRange(
      start: start,
      endInclusive: endInclusive,
      style: _resolveStyle(
        preferredStyleId: styleId,
        fallbackStyleId: 'management',
      ),
    );
  }

  Future<String?> buildDateRange({
    required DateTime start,
    required DateTime endInclusive,
    String? styleId,
  }) {
    final normalizedStart = _normalizeDay(start);
    final normalizedEnd = _normalizeDay(endInclusive);
    final rangeStart = normalizedStart.isBefore(normalizedEnd)
        ? normalizedStart
        : normalizedEnd;
    final rangeEnd = normalizedStart.isBefore(normalizedEnd)
        ? normalizedEnd
        : normalizedStart;
    return _buildRange(
      start: rangeStart,
      endInclusive: rangeEnd,
      style: _resolveStyle(
        preferredStyleId: styleId,
        fallbackStyleId: _resolveRangeFallbackStyle(
          start: rangeStart,
          endInclusive: rangeEnd,
        ),
      ),
    );
  }

  Future<String> buildQuery({
    required String displayText,
    DateTime? start,
    DateTime? endInclusive,
    String? keyword,
    List<String> statusIds = const <String>[],
    List<String> affiliationNames = const <String>[],
    List<String> fields = const <String>[],
    int? limit,
  }) async {
    final normalizedFields = _normalizeFields(fields);
    final effectiveLimit = _normalizeQueryLimit(limit);
    final range = _resolveQueryRange(
      start: start,
      endInclusive: endInclusive,
      fallbackEndInclusive: _normalizeDay(_nowProvider()),
    );
    final entries = await _repository.listTimeEntriesInRange(
      range.start,
      range.endExclusive,
    );
    final sortedEntries = [...entries]
      ..sort((a, b) {
        final date = b.workDate.compareTo(a.workDate);
        if (date != 0) return date;
        return b.createdAt.compareTo(a.createdAt);
      });

    final taskIds = sortedEntries.map((entry) => entry.taskId).toSet();
    final allTasks = await _repository.listTasks();
    final tasksById = <int, WorkTask>{
      for (final task in allTasks)
        if (task.id != null && taskIds.contains(task.id)) task.id!: task,
    };
    final taskAffiliationNames = await _buildTaskAffiliationNames(
      tasksById.values,
    );

    final normalizedKeyword = keyword?.trim() ?? '';
    final normalizedStatuses = statusIds
        .map((statusId) => statusId.trim())
        .where((statusId) => statusId.isNotEmpty)
        .toSet();
    final normalizedAffiliations = affiliationNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet();

    final matchedRecords = <_WorkLogQueryRecord>[];
    for (final entry in sortedEntries) {
      final task = tasksById[entry.taskId];
      if (task == null) continue;
      final affiliations = taskAffiliationNames[entry.taskId] ?? const [];
      if (!_matchesStatus(task.status, normalizedStatuses)) continue;
      if (!_matchesAffiliations(affiliations, normalizedAffiliations)) {
        continue;
      }
      if (!_matchesKeyword(
        task: task,
        entry: entry,
        keyword: normalizedKeyword,
      )) {
        continue;
      }
      matchedRecords.add(
        _WorkLogQueryRecord(
          task: task,
          entry: entry,
          affiliations: affiliations,
        ),
      );
    }

    final visibleRecords = matchedRecords.length <= effectiveLimit
        ? matchedRecords
        : matchedRecords.sublist(0, effectiveLimit);
    final totalMinutes = matchedRecords.fold<int>(
      0,
      (sum, record) => sum + record.entry.minutes,
    );
    final uniqueTaskIds = matchedRecords
        .map((record) => record.task.id)
        .whereType<int>()
        .toSet();
    final recordLines = <String>[
      for (int i = 0; i < visibleRecords.length; i++)
        '${i + 1}. ${_buildQueryRecordLine(visibleRecords[i], normalizedFields)}',
    ];

    final timeRangeText = start != null || endInclusive != null
        ? '${_formatDate(range.start)} 至 ${_formatDate(range.endInclusive)}（含）'
        : '全部时间';
    final statusText = normalizedStatuses.isEmpty
        ? '全部'
        : normalizedStatuses.join('、');
    final affiliationText = normalizedAffiliations.isEmpty
        ? '全部'
        : normalizedAffiliations.join('、');

    return '''
以下是工作记录查询结果（仅来自本地已保存数据）：
- 数据安全边界：${WorkLogAiSummaryPrompts.localDataSafetyNotice}
- 用户问题：$displayText
- 时间范围：$timeRangeText
- 关键词：${normalizedKeyword.isEmpty ? '未指定' : normalizedKeyword}
- 任务状态：$statusText
- 归属标签：$affiliationText
- 返回字段：${normalizedFields.join('、')}
- 返回上限：$effectiveLimit
- 命中记录数：${matchedRecords.length}
- 命中任务数：${uniqueTaskIds.length}
${normalizedFields.contains('minutes') ? '- 命中总工时：$totalMinutes 分钟' : ''}

记录列表：
${recordLines.isEmpty ? '- (无)' : recordLines.join('\n')}

回答要求：
1) 仅基于以上查询结果回答用户问题。
2) 若命中为空，明确告知“未找到符合条件的工作记录”。
3) 不要编造未返回字段的内容；若用户追问未返回字段，先说明当前查询未返回该字段。
4) 若用户希望继续缩小范围，可建议补充时间、关键词、状态、归属或字段要求。
''';
  }

  Future<String?> _buildRange({
    required DateTime start,
    required DateTime endInclusive,
    required WorkLogAiSummaryStyle style,
  }) async {
    final endExclusive = DateTime(
      endInclusive.year,
      endInclusive.month,
      endInclusive.day + 1,
    );
    final entries = await _repository.listTimeEntriesInRange(
      start,
      endExclusive,
    );
    if (entries.isEmpty) return null;

    final taskIds = entries.map((e) => e.taskId).toSet();
    final allTasks = await _repository.listTasks();
    final selectedTasks = allTasks
        .where((t) => t.id != null && taskIds.contains(t.id))
        .toList(growable: false);
    final taskAffiliationNames = await _buildTaskAffiliationNames(
      selectedTasks,
    );

    final taskTitleById = <int, String>{
      for (final task in selectedTasks)
        if (task.id != null) task.id!: task.title,
    };

    return WorkLogAiSummaryPrompts.buildPrompt(
      startDate: start,
      endDate: endInclusive,
      style: style,
      selectedTasks: selectedTasks,
      selectedAffiliationNames: const [],
      filteredEntries: entries,
      taskTitleById: taskTitleById,
      taskAffiliationNames: taskAffiliationNames,
    );
  }

  Future<Map<int, List<String>>> _buildTaskAffiliationNames(
    Iterable<WorkTask> tasks,
  ) async {
    final tagRepository = _tagRepository;
    if (tagRepository == null) {
      return const <int, List<String>>{};
    }
    final taskIds = tasks.map((task) => task.id).whereType<int>().toList();
    if (taskIds.isEmpty) {
      return const <int, List<String>>{};
    }
    final tagsByTaskId = await tagRepository.listTagsForWorkTasks(taskIds);
    return <int, List<String>>{
      for (final entry in tagsByTaskId.entries)
        entry.key: entry.value
            .map((tag) => tag.name.trim())
            .where((name) => name.isNotEmpty)
            .toList(growable: false),
    };
  }

  static String _buildQueryRecordLine(
    _WorkLogQueryRecord record,
    List<String> fields,
  ) {
    final fieldParts = <String>[];
    for (final field in fields) {
      switch (field) {
        case 'work_date':
          fieldParts.add('work_date=${_formatDate(record.entry.workDate)}');
          break;
        case 'task_title':
          fieldParts.add('task_title=${record.task.title}');
          break;
        case 'task_status':
          fieldParts.add('task_status=${_statusId(record.task.status)}');
          break;
        case 'affiliations':
          fieldParts.add(
            'affiliations=${record.affiliations.isEmpty ? '未设置' : record.affiliations.join('/')}',
          );
          break;
        case 'minutes':
          fieldParts.add('minutes=${record.entry.minutes}');
          break;
        case 'content':
          fieldParts.add(
            'content=${record.entry.content.trim().isEmpty ? '（无内容）' : record.entry.content.trim()}',
          );
          break;
        case 'task_description':
          fieldParts.add(
            'task_description=${record.task.description.trim().isEmpty ? '（无描述）' : record.task.description.trim()}',
          );
          break;
        case 'task_id':
          fieldParts.add('task_id=${record.task.id ?? record.entry.taskId}');
          break;
      }
    }
    return fieldParts.join(' | ');
  }

  static bool _matchesKeyword({
    required WorkTask task,
    required WorkTimeEntry entry,
    required String keyword,
  }) {
    final normalizedKeyword = keyword.trim().toLowerCase();
    if (normalizedKeyword.isEmpty) return true;
    final text = [
      task.title,
      task.description,
      entry.content,
    ].join('\n').toLowerCase();
    final subKeywords = _generateSubKeywords(normalizedKeyword);
    for (final subKeyword in subKeywords) {
      if (text.contains(subKeyword)) return true;
    }
    return false;
  }

  static List<String> _generateSubKeywords(String keyword) {
    final normalized = keyword.trim();
    if (normalized.isEmpty) return const <String>[];
    final length = normalized.length;
    if (length <= 2) return <String>[normalized];
    final subKeywords = <String>{normalized};
    for (int len = 2; len < length; len++) {
      for (int start = 0; start <= length - len; start++) {
        subKeywords.add(normalized.substring(start, start + len));
      }
    }
    return subKeywords.toList(growable: false);
  }

  static bool _matchesStatus(
    WorkTaskStatus status,
    Set<String> allowedStatusIds,
  ) {
    if (allowedStatusIds.isEmpty) return true;
    return allowedStatusIds.contains(_statusId(status));
  }

  static bool _matchesAffiliations(
    List<String> affiliations,
    Set<String> allowedAffiliationNames,
  ) {
    if (allowedAffiliationNames.isEmpty) return true;
    final normalized = affiliations
        .map((name) => name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    for (final allowedName in allowedAffiliationNames) {
      final subKeywords = _generateSubKeywords(allowedName.toLowerCase());
      for (final subKeyword in subKeywords) {
        for (final affiliation in normalized) {
          if (affiliation.contains(subKeyword)) return true;
        }
      }
    }
    return false;
  }

  static List<String> _normalizeFields(List<String> fields) {
    if (fields.isEmpty) return _defaultQueryFields;
    final normalized = <String>[];
    for (final rawField in fields) {
      final field = _normalizeFieldName(rawField);
      if (field == null || normalized.contains(field)) continue;
      normalized.add(field);
    }
    return normalized.isEmpty ? _defaultQueryFields : normalized;
  }

  static String? _normalizeFieldName(String rawField) {
    final field = rawField.trim().toLowerCase();
    switch (field) {
      case 'work_date':
      case 'date':
        return 'work_date';
      case 'task_title':
      case 'task':
      case 'title':
        return 'task_title';
      case 'task_status':
      case 'status':
        return 'task_status';
      case 'affiliations':
      case 'affiliation':
      case 'tags':
        return 'affiliations';
      case 'minutes':
      case 'duration':
      case 'work_minutes':
        return 'minutes';
      case 'content':
      case 'entry_content':
        return 'content';
      case 'task_description':
      case 'description':
        return 'task_description';
      case 'task_id':
      case 'id':
        return 'task_id';
      default:
        return null;
    }
  }

  static int _normalizeQueryLimit(int? limit) {
    if (limit == null || limit <= 0) return 20;
    return limit > 100 ? 100 : limit;
  }

  static _QueryRange _resolveQueryRange({
    required DateTime? start,
    required DateTime? endInclusive,
    required DateTime fallbackEndInclusive,
  }) {
    final normalizedEnd = endInclusive == null
        ? _normalizeDay(fallbackEndInclusive)
        : _normalizeDay(endInclusive);
    final normalizedStart = start == null
        ? DateTime(1970, 1, 1)
        : _normalizeDay(start);
    final range = normalizedStart.isAfter(normalizedEnd)
        ? _QueryRange(start: normalizedEnd, endInclusive: normalizedStart)
        : _QueryRange(start: normalizedStart, endInclusive: normalizedEnd);
    return range;
  }

  static DateTime _normalizeDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  static WorkLogAiSummaryStyle _resolveStyle({
    required String fallbackStyleId,
    String? preferredStyleId,
  }) {
    final styleId = preferredStyleId?.trim();
    if (styleId != null && styleId.isNotEmpty) {
      return WorkLogAiSummaryPrompts.resolveStyle(styleId);
    }
    return WorkLogAiSummaryPrompts.resolveStyle(fallbackStyleId);
  }

  static String _resolveRangeFallbackStyle({
    required DateTime start,
    required DateTime endInclusive,
  }) {
    final totalDays = endInclusive.difference(start).inDays + 1;
    if (totalDays <= 14) return 'concise';
    if (totalDays <= 62) return 'review';
    return 'management';
  }

  static String _formatDate(DateTime dateTime) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}';
  }

  static String _statusId(WorkTaskStatus status) {
    return switch (status) {
      WorkTaskStatus.todo => 'todo',
      WorkTaskStatus.doing => 'doing',
      WorkTaskStatus.done => 'done',
      WorkTaskStatus.canceled => 'canceled',
    };
  }
}

class _WorkLogQueryRecord {
  final WorkTask task;
  final WorkTimeEntry entry;
  final List<String> affiliations;

  const _WorkLogQueryRecord({
    required this.task,
    required this.entry,
    required this.affiliations,
  });
}

class _QueryRange {
  final DateTime start;
  final DateTime endInclusive;

  const _QueryRange({required this.start, required this.endInclusive});

  DateTime get endExclusive =>
      DateTime(endInclusive.year, endInclusive.month, endInclusive.day + 1);
}
