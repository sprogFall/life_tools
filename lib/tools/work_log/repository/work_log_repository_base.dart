import '../models/operation_log.dart';
import '../models/work_task.dart';
import '../models/work_time_entry.dart';

abstract class WorkLogRepositoryBase {
  Future<int> createTask(WorkTask task);
  Future<WorkTask?> getTask(int id);

  Future<List<WorkTask>> listTasks({
    WorkTaskStatus? status,
    String? keyword,
  });

  Future<void> updateTask(WorkTask task);
  Future<void> deleteTask(int id);

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
}

