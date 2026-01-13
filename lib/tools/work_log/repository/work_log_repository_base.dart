import '../models/operation_log.dart';
import '../models/work_task.dart';
import '../models/work_time_entry.dart';

abstract class WorkLogRepositoryBase {
  Future<int> createTask(WorkTask task);
  Future<WorkTask?> getTask(int id);

  Future<List<WorkTask>> listTasks({
    WorkTaskStatus? status,
    List<WorkTaskStatus>? statuses,
    String? keyword,
  });

  Future<void> updateTask(WorkTask task);
  Future<void> deleteTask(int id);
  Future<int> getTotalMinutesForTask(int taskId);

  Future<int> createTimeEntry(WorkTimeEntry entry);
  Future<WorkTimeEntry?> getTimeEntry(int id);
  Future<void> updateTimeEntry(WorkTimeEntry entry);
  Future<void> deleteTimeEntry(int id);
  Future<List<WorkTimeEntry>> listTimeEntriesForTask(int taskId);

  Future<List<WorkTimeEntry>> listTimeEntriesInRange(
    DateTime startInclusive,
    DateTime endExclusive,
  );

  Future<int> getTotalMinutesForDate(DateTime date);

  Future<int> createOperationLog(OperationLog log);
  Future<List<OperationLog>> listOperationLogs({
    int? limit,
    int? offset,
    TargetType? targetType,
    int? targetId,
  });
  Future<int> getOperationLogCount();

  // 同步相关方法：批量导入数据
  /// 从服务端数据批量导入任务（覆盖本地）
  Future<void> importTasksFromServer(List<Map<String, dynamic>> tasksData);

  /// 从服务端数据批量导入工时记录（覆盖本地）
  Future<void> importTimeEntriesFromServer(
    List<Map<String, dynamic>> entriesData,
  );

  /// 从服务端数据批量导入操作日志（覆盖本地）
  Future<void> importOperationLogsFromServer(
    List<Map<String, dynamic>> logsData,
  );
}
