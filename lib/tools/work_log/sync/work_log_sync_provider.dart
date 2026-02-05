import '../../../core/sync/interfaces/tool_sync_provider.dart';
import '../../../core/tags/tag_repository.dart';
import '../repository/work_log_repository_base.dart';

/// WorkLog工具的同步提供者
class WorkLogSyncProvider implements ToolSyncProvider {
  final WorkLogRepositoryBase _repository;
  final TagRepository _tagRepository;

  WorkLogSyncProvider({
    required WorkLogRepositoryBase repository,
    TagRepository? tagRepository,
  }) : _repository = repository,
       _tagRepository = tagRepository ?? TagRepository();

  @override
  String get toolId => 'work_log';

  @override
  Future<Map<String, dynamic>> exportData() async {
    // 导出所有任务、工时记录、操作日志
    final tasks = await _repository.listTasks();
    final allTimeEntries = <Map<String, dynamic>>[];

    // 收集所有任务的工时记录
    for (final task in tasks) {
      if (task.id != null) {
        final entries = await _repository.listTimeEntriesForTask(task.id!);
        allTimeEntries.addAll(entries.map((e) => e.toMap()));
      }
    }

    // 导出操作日志（限制最近1000条，避免数据量过大）
    final operationLogs = await _repository.listOperationLogs(limit: 1000);
    final taskTags = await _tagRepository.exportWorkTaskTags();

    return {
      'version': 1,
      'data': {
        'tasks': tasks.map((t) => t.toMap()).toList(),
        'time_entries': allTimeEntries,
        'task_tags': taskTags,
        'operation_logs': operationLogs.map((l) => l.toMap()).toList(),
      },
    };
  }

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    // 验证数据格式
    final version = data['version'] as int?;
    if (version == null || version != 1) {
      throw Exception('不支持的数据版本: $version');
    }

    final dataMap = data['data'] as Map<String, dynamic>?;
    if (dataMap == null) {
      throw Exception('数据格式错误：缺少data字段');
    }

    final tasks = (dataMap['tasks'] as List<dynamic>?) ?? const [];
    final timeEntries = (dataMap['time_entries'] as List<dynamic>?) ?? const [];
    final hasTaskTags = dataMap.containsKey('task_tags');
    final taskTags = (dataMap['task_tags'] as List<dynamic>?) ?? const [];
    final operationLogs =
        (dataMap['operation_logs'] as List<dynamic>?) ?? const [];

    // 批量导入（使用事务确保原子性）
    await _repository.importTasksFromServer(
      tasks.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
    await _repository.importTimeEntriesFromServer(
      timeEntries.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
    // 兼容：旧快照可能缺少 task_tags 字段；仅当字段存在时才覆盖导入（允许清空）。
    if (hasTaskTags) {
      await _tagRepository.importWorkTaskTagsFromServer(
        taskTags.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    }
    await _repository.importOperationLogsFromServer(
      operationLogs.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
  }
}
