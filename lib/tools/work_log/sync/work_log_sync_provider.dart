import '../../../core/sync/interfaces/tool_sync_provider.dart';
import '../../../core/tag/services/tag_service.dart';
import '../repository/work_log_repository_base.dart';

/// WorkLog工具的同步提供者
class WorkLogSyncProvider implements ToolSyncProvider {
  final WorkLogRepositoryBase _repository;

  WorkLogSyncProvider({required WorkLogRepositoryBase repository})
    : _repository = repository;

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
    
    // 导出任务标签关联（使用TagRepository的接口获取）
    final tagService = TagService();
    final workTaskTags = <Map<String, dynamic>>[];
    
    for (final task in tasks) {
      if (task.id != null) {
        final tags = await tagService.getTagsForTask(task.id!);
        for (final tag in tags) {
          workTaskTags.add({
            'tag_id': tag.id,
            'task_id': task.id,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
      }
    }

    return {
      'version': 2,
      'data': {
        'tasks': tasks.map((t) => t.toMap()).toList(),
        'time_entries': allTimeEntries,
        'operation_logs': operationLogs.map((l) => l.toMap()).toList(),
        'work_task_tags': workTaskTags,
      },
    };
  }

  @override
  Future<void> importData(Map<String, dynamic> data) async {
    // 验证数据格式
    final version = data['version'] as int?;
    if (version == null || (version != 1 && version != 2)) {
      throw Exception('不支持的数据版本: $version');
    }

    final dataMap = data['data'] as Map<String, dynamic>?;
    if (dataMap == null) {
      throw Exception('数据格式错误：缺少data字段');
    }

    final tasks = (dataMap['tasks'] as List<dynamic>?) ?? [];
    final timeEntries = (dataMap['time_entries'] as List<dynamic>?) ?? [];
    final operationLogs = (dataMap['operation_logs'] as List<dynamic>?) ?? [];
    
    // 版本2新增：任务标签关联
    final workTaskTags = version == 2 
      ? (dataMap['work_task_tags'] as List<dynamic>?) ?? []
      : [];

    // 批量导入（使用事务确保原子性）
    await _repository.importTasksFromServer(
      tasks.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
    await _repository.importTimeEntriesFromServer(
      timeEntries.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
    await _repository.importOperationLogsFromServer(
      operationLogs.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
    );
    
    // 版本2新增：导入任务标签关联数据
    if (workTaskTags.isNotEmpty) {
      await _repository.importWorkTaskTagsFromServer(
        workTaskTags.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    }
  }
}
