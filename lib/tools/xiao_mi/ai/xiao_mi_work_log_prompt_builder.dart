import '../../work_log/ai/work_log_ai_summary_prompts.dart';
import '../../work_log/repository/work_log_repository_base.dart';

class XiaoMiWorkLogSummaryPromptBuilder {
  final WorkLogRepositoryBase _repository;
  final DateTime Function() _nowProvider;

  const XiaoMiWorkLogSummaryPromptBuilder({
    required WorkLogRepositoryBase repository,
    DateTime Function()? nowProvider,
  }) : _repository = repository,
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
      taskAffiliationNames: const <int, List<String>>{},
    );
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
}

class XiaoMiWorkLogYearSummaryPromptBuilder {
  final WorkLogRepositoryBase _repository;
  final DateTime Function() _nowProvider;

  const XiaoMiWorkLogYearSummaryPromptBuilder({
    required WorkLogRepositoryBase repository,
    DateTime Function()? nowProvider,
  }) : _repository = repository,
       _nowProvider = nowProvider ?? DateTime.now;

  Future<String?> build() async {
    final builder = XiaoMiWorkLogSummaryPromptBuilder(
      repository: _repository,
      nowProvider: _nowProvider,
    );
    return builder.buildCurrentYear();
  }
}
