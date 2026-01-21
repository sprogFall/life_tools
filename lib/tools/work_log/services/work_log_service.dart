import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/tags/models/tag.dart';
import '../../../core/tags/tag_repository.dart';
import '../models/operation_log.dart';
import '../models/work_task.dart';
import '../models/work_time_entry.dart';
import '../repository/work_log_repository_base.dart';

class WorkLogService extends ChangeNotifier {
  static const String _statusFiltersKey = 'work_log_status_filters';
  static const String _tagFiltersKey = 'work_log_tag_filters';
  static const String _customSortEnabledKey = 'work_log_task_custom_sort';

  final WorkLogRepositoryBase _repository;
  final TagRepository? _tagRepository;

  bool _filtersLoaded = false;
  bool _customSortEnabled = false;

  WorkLogService({
    required WorkLogRepositoryBase repository,
    TagRepository? tagRepository,
  }) : _repository = repository,
       _tagRepository = tagRepository;

  bool _disposed = false;

  bool _loadingTasks = false;
  bool get loadingTasks => _loadingTasks;

  List<WorkTask> _tasks = [];
  List<WorkTask> get tasks => List.unmodifiable(_tasks);

  List<WorkTask> _allTasks = [];
  List<WorkTask> get allTasks => List.unmodifiable(_allTasks);

  List<WorkTaskStatus> _statusFilters = [
    WorkTaskStatus.todo,
    WorkTaskStatus.doing,
  ];
  List<WorkTaskStatus> get statusFilters => List.unmodifiable(_statusFilters);

  List<int> _tagFilters = [];
  List<int> get tagFilters => List.unmodifiable(_tagFilters);

  List<Tag> _availableTags = const [];
  List<Tag> get availableTags => List.unmodifiable(_availableTags);

  final Map<int, int> _taskTotalMinutes = {};
  final Map<int, List<Tag>> _taskTags = {};

  // 任务列表分页状态
  static const int _taskPageSize = 10;
  int _taskOffset = 0;
  bool _hasMoreTasks = true;
  bool get hasMoreTasks => _hasMoreTasks;

  Future<void> loadTasks() async {
    if (_disposed) return;
    _loadingTasks = true;
    _taskOffset = 0;
    _hasMoreTasks = true;
    _tasks = [];
    _taskTotalMinutes.clear();
    _taskTags.clear();
    _safeNotify();

    try {
      // 只在首次加载时读取保存的筛选状态
      if (!_filtersLoaded) {
        final prefs = await SharedPreferences.getInstance();
        final savedStatuses = prefs.getStringList(_statusFiltersKey);
        if (savedStatuses != null && savedStatuses.isNotEmpty) {
          _statusFilters = savedStatuses
              .map((s) => WorkTaskStatus.values.firstWhere(
                    (e) => e.name == s,
                    orElse: () => WorkTaskStatus.todo,
                  ))
              .toList();
        }
        final savedTags = prefs.getStringList(_tagFiltersKey);
        if (savedTags != null) {
          _tagFilters = savedTags.map((s) => int.tryParse(s) ?? 0).where((id) => id > 0).toList();
        }
        _customSortEnabled = prefs.getBool(_customSortEnabledKey) ?? false;
        _filtersLoaded = true;
      }

      if (_tagRepository != null) {
        _availableTags = await _tagRepository.listTagsForTool('work_log');
      } else {
        _availableTags = const [];
      }

      if (_tagRepository != null && _tagFilters.isNotEmpty) {
        final availableIds =
            _availableTags.map((t) => t.id).whereType<int>().toSet();
        final next = _tagFilters.where(availableIds.contains).toList();
        if (!listEquals(next, _tagFilters)) {
          _tagFilters = next;
          await _saveFilters();
        }
      }

      _allTasks = await _repository.listTasks();

      final firstPage = await _repository.listTasks(
        statuses: _statusFilters,
        tagIds: _tagFilters.isEmpty ? null : _tagFilters,
        limit: _taskPageSize,
        offset: 0,
      );

      _tasks = firstPage;
      _taskOffset = firstPage.length;
      _hasMoreTasks = firstPage.length >= _taskPageSize;

      await _loadTaskTotalMinutes(firstPage);
      await _loadTaskTags(firstPage);
    } finally {
      _loadingTasks = false;
      _safeNotify();
    }
  }

  Future<void> loadMoreTasks() async {
    if (_disposed || !_hasMoreTasks || _loadingTasks) return;

    _loadingTasks = true;
    _safeNotify();

    try {
      final newTasks = await _repository.listTasks(
        statuses: _statusFilters,
        tagIds: _tagFilters.isEmpty ? null : _tagFilters,
        limit: _taskPageSize,
        offset: _taskOffset,
      );

      if (newTasks.isEmpty || newTasks.length < _taskPageSize) {
        _hasMoreTasks = false;
      }

      _tasks = [..._tasks, ...newTasks];
      _taskOffset += newTasks.length;

      await _loadTaskTotalMinutes(newTasks);
      await _loadTaskTags(newTasks);
    } finally {
      _loadingTasks = false;
      _safeNotify();
    }
  }

  Future<void> _loadTaskTotalMinutes(List<WorkTask> tasks) async {
    for (final task in tasks) {
      if (task.id != null) {
        _taskTotalMinutes[task.id!] = await _repository.getTotalMinutesForTask(
          task.id!,
        );
      }
    }
  }

  Future<void> _loadTaskTags(List<WorkTask> tasks) async {
    final repo = _tagRepository;
    if (repo == null) return;

    final ids = tasks.where((t) => t.id != null).map((t) => t.id!).toList();
    if (ids.isEmpty) return;

    final map = await repo.listTagsForWorkTasks(ids);
    _taskTags.addAll(map);
  }

  List<Tag> getTagsForTask(int taskId) {
    return _taskTags[taskId] ?? const [];
  }

  int getTaskTotalMinutes(int taskId) {
    return _taskTotalMinutes[taskId] ?? 0;
  }

  void setStatusFilters(List<WorkTaskStatus> filters) {
    _statusFilters = filters;
    _saveFilters();
    loadTasks();
  }

  void setTagFilters(List<int> tagIds) {
    _tagFilters = tagIds;
    _saveFilters();
    loadTasks();
  }

  Future<void> _saveFilters() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _statusFiltersKey,
      _statusFilters.map((s) => s.name).toList(),
    );
    await prefs.setStringList(
      _tagFiltersKey,
      _tagFilters.map((id) => id.toString()).toList(),
    );
  }

  int getTaskCountByStatus(WorkTaskStatus status) {
    return _allTasks.where((t) => t.status == status).length;
  }

  Future<int> createTask(WorkTask task, {List<int> tagIds = const []}) async {
    final taskForCreate = _customSortEnabled
        ? task.copyWith(sortIndex: DateTime.now().millisecondsSinceEpoch)
        : task;
    final id = await _repository.createTask(taskForCreate);

    final repo = _tagRepository;
    if (repo != null && tagIds.isNotEmpty) {
      try {
        await repo.setTagsForWorkTask(id, tagIds);
      } catch (_) {
        // 标签保存失败不影响任务创建
      }
    }

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

  Future<void> updateTask(WorkTask task, {List<int>? tagIds}) async {
    final oldTask = await _repository.getTask(task.id!);
    await _repository.updateTask(task);

    final changes = _generateTaskChangeSummary(oldTask, task);

    final repo = _tagRepository;
    if (repo != null && tagIds != null) {
      try {
        await repo.setTagsForWorkTask(task.id!, tagIds);
      } catch (_) {
        // 标签保存失败不影响任务更新
      }
    }

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

  Future<List<int>> listTagIdsForTask(int taskId) async {
    final repo = _tagRepository;
    if (repo == null) return const [];
    return repo.listTagIdsForWorkTask(taskId);
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

  Future<List<WorkTask>> listAllFilteredTasksForSorting() async {
    return _repository.listTasks(
      statuses: _statusFilters,
      tagIds: _tagFilters.isEmpty ? null : _tagFilters,
    );
  }

  Future<void> saveTaskSorting(List<WorkTaskSortOrder> orders) async {
    await _repository.updateTaskSorting(orders);

    final prefs = await SharedPreferences.getInstance();
    _customSortEnabled = true;
    await prefs.setBool(_customSortEnabledKey, true);

    await loadTasks();
  }

  Future<WorkTask?> getTask(int id) async {
    return _repository.getTask(id);
  }

  Future<int> getTotalMinutesForTask(int taskId) async {
    return _repository.getTotalMinutesForTask(taskId);
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

  Future<List<WorkTimeEntry>> listTimeEntriesForTask(
    int taskId, {
    int? limit,
    int? offset,
  }) async {
    return _repository.listTimeEntriesForTask(
      taskId,
      limit: limit,
      offset: offset,
    );
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
