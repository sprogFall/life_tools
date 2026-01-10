import 'package:flutter/foundation.dart';
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

  Future<void> loadTasks() async {
    if (_disposed) return;
    _loadingTasks = true;
    _safeNotify();
    try {
      _tasks = await _repository.listTasks();
    } finally {
      _loadingTasks = false;
      _safeNotify();
    }
  }

  Future<int> createTask(WorkTask task) async {
    final id = await _repository.createTask(task);
    await loadTasks();
    return id;
  }

  Future<void> updateTask(WorkTask task) async {
    await _repository.updateTask(task);
    await loadTasks();
  }

  Future<void> deleteTask(int id) async {
    await _repository.deleteTask(id);
    await loadTasks();
  }

  Future<WorkTask?> getTask(int id) async {
    return _repository.getTask(id);
  }

  Future<int> createTimeEntry(WorkTimeEntry entry) async {
    final id = await _repository.createTimeEntry(entry);
    _safeNotify();
    return id;
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
