import 'package:life_tools/tools/work_log/models/operation_log.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository_base.dart';

class FakeWorkLogRepository implements WorkLogRepositoryBase {
  int _taskId = 0;
  int _entryId = 0;
  int _logId = 0;
  final List<WorkTask> _tasks = [];
  final List<WorkTimeEntry> _entries = [];
  final List<OperationLog> _logs = [];

  @override
  Future<int> createTask(WorkTask task) async {
    final id = ++_taskId;
    _tasks.add(task.copyWith(id: id));
    return id;
  }

  @override
  Future<void> deleteTask(int id) async {
    _tasks.removeWhere((t) => t.id == id);
    _entries.removeWhere((e) => e.taskId == id);
  }

  @override
  Future<WorkTask?> getTask(int id) async {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Future<int> getTotalMinutesForTask(int taskId) async {
    return _entries
        .where((e) => e.taskId == taskId)
        .fold<int>(0, (sum, e) => sum + e.minutes);
  }

  @override
  Future<List<WorkTask>> listTasks({
    WorkTaskStatus? status,
    List<WorkTaskStatus>? statuses,
    String? keyword,
    List<int>? tagIds,
    int? limit,
    int? offset,
  }) async {
    Iterable<WorkTask> result = _tasks;
    if (status != null) {
      result = result.where((t) => t.status == status);
    } else if (statuses != null && statuses.isNotEmpty) {
      result = result.where((t) => statuses.contains(t.status));
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      final lower = keyword.trim().toLowerCase();
      result = result.where(
        (t) =>
            t.title.toLowerCase().contains(lower) ||
            t.description.toLowerCase().contains(lower),
      );
    }
    var list = result.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (offset != null && offset > 0) {
      list = list.skip(offset).toList();
    }
    if (limit != null && limit > 0) {
      list = list.take(limit).toList();
    }
    return list;
  }

  @override
  Future<void> updateTask(WorkTask task) async {
    final id = task.id;
    if (id == null) return;
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index >= 0) _tasks[index] = task;
  }

  @override
  Future<int> createTimeEntry(WorkTimeEntry entry) async {
    final id = ++_entryId;
    _entries.add(entry.copyWith(id: id));
    return id;
  }

  @override
  Future<WorkTimeEntry?> getTimeEntry(int id) async {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Future<void> updateTimeEntry(WorkTimeEntry entry) async {
    final id = entry.id;
    if (id == null) return;
    final index = _entries.indexWhere((e) => e.id == id);
    if (index >= 0) _entries[index] = entry;
  }

  @override
  Future<void> deleteTimeEntry(int id) async {
    _entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<int> getTotalMinutesForDate(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    return _entries
        .where((e) => e.workDate == day)
        .fold<int>(0, (sum, e) => sum + e.minutes);
  }

  @override
  Future<List<WorkTimeEntry>> listTimeEntriesForTask(
    int taskId, {
    int? limit,
    int? offset,
  }) async {
    var list = _entries.where((e) => e.taskId == taskId).toList();
    if (offset != null && offset > 0) {
      list = list.skip(offset).toList();
    }
    if (limit != null && limit > 0) {
      list = list.take(limit).toList();
    }
    return list;
  }

  @override
  Future<List<WorkTimeEntry>> listTimeEntriesInRange(
    DateTime startInclusive,
    DateTime endExclusive,
  ) async {
    final start = DateTime(
      startInclusive.year,
      startInclusive.month,
      startInclusive.day,
    );
    final end = DateTime(
      endExclusive.year,
      endExclusive.month,
      endExclusive.day,
    );
    return _entries
        .where((e) => !e.workDate.isBefore(start) && e.workDate.isBefore(end))
        .toList();
  }

  @override
  Future<int> createOperationLog(OperationLog log) async {
    final id = ++_logId;
    _logs.add(
      OperationLog(
        id: id,
        operationType: log.operationType,
        targetType: log.targetType,
        targetId: log.targetId,
        targetTitle: log.targetTitle,
        beforeSnapshot: log.beforeSnapshot,
        afterSnapshot: log.afterSnapshot,
        summary: log.summary,
        createdAt: log.createdAt,
      ),
    );
    return id;
  }

  @override
  Future<List<OperationLog>> listOperationLogs({
    int? limit,
    int? offset,
    TargetType? targetType,
    int? targetId,
  }) async {
    Iterable<OperationLog> result = _logs;
    if (targetType != null) {
      result = result.where((l) => l.targetType == targetType);
    }
    if (targetId != null) {
      result = result.where((l) => l.targetId == targetId);
    }
    var list = result.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (offset != null && offset > 0) {
      list = list.skip(offset).toList();
    }
    if (limit != null && limit > 0) {
      list = list.take(limit).toList();
    }
    return list;
  }

  @override
  Future<int> getOperationLogCount() async {
    return _logs.length;
  }

  @override
  Future<void> importTasksFromServer(
    List<Map<String, dynamic>> tasksData,
  ) async {
    _tasks.clear();
    for (final taskMap in tasksData) {
      _tasks.add(WorkTask.fromMap(taskMap));
    }
  }

  @override
  Future<void> importTimeEntriesFromServer(
    List<Map<String, dynamic>> entriesData,
  ) async {
    _entries.clear();
    for (final entryMap in entriesData) {
      _entries.add(WorkTimeEntry.fromMap(entryMap));
    }
  }

  @override
  Future<void> importOperationLogsFromServer(
    List<Map<String, dynamic>> logsData,
  ) async {
    _logs.clear();
    for (final logMap in logsData) {
      _logs.add(OperationLog.fromMap(logMap));
    }
  }
}
