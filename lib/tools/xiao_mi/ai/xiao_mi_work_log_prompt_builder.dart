import '../../work_log/ai/work_log_ai_summary_prompts.dart';
import '../../work_log/repository/work_log_repository_base.dart';

class XiaoMiWorkLogYearSummaryPromptBuilder {
  final WorkLogRepositoryBase _repository;
  final DateTime Function() _nowProvider;

  const XiaoMiWorkLogYearSummaryPromptBuilder({
    required WorkLogRepositoryBase repository,
    DateTime Function()? nowProvider,
  }) : _repository = repository,
       _nowProvider = nowProvider ?? DateTime.now;

  Future<String?> build() async {
    final now = _nowProvider();
    final year = now.year;
    final start = DateTime(year, 1, 1);
    final endExclusive = DateTime(year + 1, 1, 1);
    final endInclusive = DateTime(year, 12, 31);

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
      style: _resolveDefaultStyle(),
      selectedTasks: selectedTasks,
      selectedAffiliationNames: const [],
      filteredEntries: entries,
      taskTitleById: taskTitleById,
      taskAffiliationNames: const <int, List<String>>{},
    );
  }

  static WorkLogAiSummaryStyle _resolveDefaultStyle() {
    // 年度总结更适合“管理汇报”风格：先总体再分解任务。
    return WorkLogAiSummaryPrompts.resolveStyle('management');
  }
}
