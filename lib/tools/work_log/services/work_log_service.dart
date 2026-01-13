import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/operation_log.dart';
import '../models/work_task.dart';
import '../models/work_time_entry.dart';
import '../repository/work_log_repository_base.dart';

class WorkLogService extends ChangeNotifier {
  final WorkLogRepositoryBase _repository;

  WorkLogService({required WorkLogRepositoryBase repository})
    : _repository = repository;

  bool _disposed = false;

  bool _loadingTasks = false;
  bool get loadingTasks => _loadingTasks;

  List<WorkTask> _tasks = [];
  List<WorkTask> get tasks => List.unmodifiable(_tasks);

  List<WorkTaskStatus> _statusFilters = [
    WorkTaskStatus.todo,
    WorkTaskStatus.doing,
  ];
  List<WorkTaskStatus> get statusFilters => List.unmodifiable(_statusFilters);

  final Map<int, int> _taskTotalMinutes = {};

  Future<void> loadTasks() async {
    if (_disposed) return;
    _loadingTasks = true;
    _safeNotify();
    try {
      _tasks = await _repository.listTasks(statuses: _statusFilters);
      await _loadTaskTotalMinutes();
    } finally {
      _loadingTasks = false;
      _safeNotify();
    }
  }

  Future<void> _loadTaskTotalMinutes() async {
    _taskTotalMinutes.clear();
    for (final task in _tasks) {
      if (task.id != null) {
        _taskTotalMinutes[task.id!] = await _repository.getTotalMinutesForTask(
          task.id!,
        );
      }
    }
  }

  int getTaskTotalMinutes(int taskId) {
    return _taskTotalMinutes[taskId] ?? 0;
  }

  void setStatusFilters(List<WorkTaskStatus> filters) {
    _statusFilters = filters;
    loadTasks();
  }

  Future<int> createTask(WorkTask task) async {
    final id = await _repository.createTask(task);

    await _repository.createOperationLog(
      OperationLog.create(
        operationType: OperationType.createTask,
        targetType: TargetType.task,
        targetId: id,
        targetTitle: task.title,
        afterSnapshot: jsonEncode(task.copyWith(id: id).toMap()),
        summary: '创建任务「${task.title}」',
      ),
    );

    await loadTasks();
    return id;
  }

  Future<void> updateTask(WorkTask task) async {
    final oldTask = await _repository.getTask(task.id!);
    await _repository.updateTask(task);

    final changes = _generateTaskChangeSummary(oldTask, task);

    await _repository.createOperationLog(
      OperationLog.create(
        operationType: OperationType.updateTask,
        targetType: TargetType.task,
        targetId: task.id!,
        targetTitle: task.title,
        beforeSnapshot: oldTask != null ? jsonEncode(oldTask.toMap()) : null,
        afterSnapshot: jsonEncode(task.toMap()),
        summary: changes,
      ),
    );

    await loadTasks();
  }

  Future<void> deleteTask(int id) async {
    final oldTask = await _repository.getTask(id);
    await _repository.deleteTask(id);

    await _repository.createOperationLog(
      OperationLog.create(
        operationType: OperationType.deleteTask,
        targetType: TargetType.task,
        targetId: id,
        targetTitle: oldTask?.title ?? '未知任务',
        beforeSnapshot: oldTask != null ? jsonEncode(oldTask.toMap()) : null,
        summary: '删除任务「${oldTask?.title ?? '未知'}」',
      ),
    );

    await loadTasks();
  }

  Future<WorkTask?> getTask(int id) async {
    return _repository.getTask(id);
  }

  Future<int> createTimeEntry(WorkTimeEntry entry) async {
    final id = await _repository.createTimeEntry(entry);

    // 核心逻辑：如果任务状态是 todo，自动切换为 doing
    final task = await _repository.getTask(entry.taskId);
    if (task != null && task.status == WorkTaskStatus.todo) {
      final updatedTask = task.copyWith(
        status: WorkTaskStatus.doing,
        updatedAt: DateTime.now(),
      );
      await _repository.updateTask(updatedTask);

      await _repository.createOperationLog(
        OperationLog.create(
          operationType: OperationType.updateTask,
          targetType: TargetType.task,
          targetId: task.id!,
          targetTitle: task.title,
          beforeSnapshot: jsonEncode(task.toMap()),
          afterSnapshot: jsonEncode(updatedTask.toMap()),
          summary: '任务状态自动从「待办」切换为「进行中」（因记录工时触发）',
        ),
      );
    }

    await _repository.createOperationLog(
      OperationLog.create(
        operationType: OperationType.createTimeEntry,
        targetType: TargetType.timeEntry,
        targetId: id,
        targetTitle: '${task?.title ?? ''} - ${entry.content}',
        afterSnapshot: jsonEncode(entry.copyWith(id: id).toMap()),
        summary: '为任务「${task?.title ?? ''}」记录 ${entry.minutes} 分钟工时',
      ),
    );

    _safeNotify();
    return id;
  }

  Future<void> updateTimeEntry(WorkTimeEntry entry) async {
    final oldEntry = await _repository.getTimeEntry(entry.id!);
    await _repository.updateTimeEntry(entry);

    final task = await _repository.getTask(entry.taskId);
    final changes = _generateTimeEntryChangeSummary(oldEntry, entry);

    await _repository.createOperationLog(
      OperationLog.create(
        operationType: OperationType.updateTimeEntry,
        targetType: TargetType.timeEntry,
        targetId: entry.id!,
        targetTitle: '${task?.title ?? ''} - ${entry.content}',
        beforeSnapshot: oldEntry != null ? jsonEncode(oldEntry.toMap()) : null,
        afterSnapshot: jsonEncode(entry.toMap()),
        summary: changes,
      ),
    );

    _safeNotify();
  }

  Future<void> deleteTimeEntry(int id) async {
    final oldEntry = await _repository.getTimeEntry(id);
    await _repository.deleteTimeEntry(id);

    WorkTask? task;
    if (oldEntry != null) {
      task = await _repository.getTask(oldEntry.taskId);
    }

    await _repository.createOperationLog(
      OperationLog.create(
        operationType: OperationType.deleteTimeEntry,
        targetType: TargetType.timeEntry,
        targetId: id,
        targetTitle: '${task?.title ?? ''} - ${oldEntry?.content ?? ''}',
        beforeSnapshot: oldEntry != null ? jsonEncode(oldEntry.toMap()) : null,
        summary: '删除工时记录（${oldEntry?.minutes ?? 0} 分钟）',
      ),
    );

    _safeNotify();
  }

  Future<List<WorkTimeEntry>> listTimeEntriesForTask(int taskId) async {
    return _repository.listTimeEntriesForTask(taskId);
  }

  Future<List<WorkTimeEntry>> listTimeEntriesInRange(
    DateTime startInclusive,
    DateTime endExclusive,
  ) async {
    return _repository.listTimeEntriesInRange(startInclusive, endExclusive);
  }

  Future<List<OperationLog>> listOperationLogs({
    int? limit,
    int? offset,
  }) async {
    return _repository.listOperationLogs(limit: limit, offset: offset);
  }

  Future<int> getOperationLogCount() async {
    return _repository.getOperationLogCount();
  }

  String _generateTaskChangeSummary(WorkTask? oldTask, WorkTask newTask) {
    if (oldTask == null) return '更新任务「${newTask.title}」';

    final changes = <String>[];
    if (oldTask.title != newTask.title) {
      changes.add('标题: "${oldTask.title}" -> "${newTask.title}"');
    }
    if (oldTask.status != newTask.status) {
      changes.add(
        '状态: ${_statusLabel(oldTask.status)} -> ${_statusLabel(newTask.status)}',
      );
    }
    if (oldTask.estimatedMinutes != newTask.estimatedMinutes) {
      changes.add(
        '预计工时: ${oldTask.estimatedMinutes}分钟 -> ${newTask.estimatedMinutes}分钟',
      );
    }
    if (oldTask.description != newTask.description) {
      changes.add('描述已修改');
    }

    return changes.isEmpty ? '更新任务「${newTask.title}」' : changes.join('；');
  }

  String _generateTimeEntryChangeSummary(
    WorkTimeEntry? oldEntry,
    WorkTimeEntry newEntry,
  ) {
    if (oldEntry == null) return '更新工时记录';

    final changes = <String>[];
    if (oldEntry.minutes != newEntry.minutes) {
      changes.add('时长: ${oldEntry.minutes}分钟 -> ${newEntry.minutes}分钟');
    }
    if (oldEntry.workDate != newEntry.workDate) {
      changes.add('日期已修改');
    }
    if (oldEntry.content != newEntry.content) {
      changes.add('内容已修改');
    }

    return changes.isEmpty ? '更新工时记录' : changes.join('；');
  }

  static String _statusLabel(WorkTaskStatus status) {
    return switch (status) {
      WorkTaskStatus.todo => '待办',
      WorkTaskStatus.doing => '进行中',
      WorkTaskStatus.done => '已完成',
      WorkTaskStatus.canceled => '已取消',
    };
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
