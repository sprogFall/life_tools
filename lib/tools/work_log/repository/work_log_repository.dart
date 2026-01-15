import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../models/operation_log.dart';
import '../models/work_task.dart';
import '../models/work_time_entry.dart';
import 'work_log_repository_base.dart';

class WorkLogRepository implements WorkLogRepositoryBase {
  final Future<Database> _database;

  WorkLogRepository({DatabaseHelper? dbHelper})
    : _database = (dbHelper ?? DatabaseHelper.instance).database;

  WorkLogRepository.withDatabase(Database database)
    : _database = Future.value(database);

  @override
  Future<int> createTask(WorkTask task) async {
    final db = await _database;
    return db.insert('work_tasks', task.toMap(includeId: false));
  }

  @override
  Future<WorkTask?> getTask(int id) async {
    final db = await _database;
    final results = await db.query(
      'work_tasks',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return WorkTask.fromMap(results.first);
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
    final db = await _database;

    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    if (status != null) {
      whereParts.add('status = ?');
      whereArgs.add(status.value);
    } else if (statuses != null && statuses.isNotEmpty) {
      final placeholders = List.filled(statuses.length, '?').join(',');
      whereParts.add('status IN ($placeholders)');
      whereArgs.addAll(statuses.map((s) => s.value));
    }

    if (keyword != null && keyword.trim().isNotEmpty) {
      whereParts.add('(title LIKE ? OR description LIKE ?)');
      final like = '%${keyword.trim()}%';
      whereArgs
        ..add(like)
        ..add(like);
    }

    if (tagIds != null && tagIds.isNotEmpty) {
      final placeholders = List.filled(tagIds.length, '?').join(',');
      // 没有标签的任务始终显示，有标签的任务需要匹配筛选条件
      whereParts.add('''
(
  NOT EXISTS (SELECT 1 FROM work_task_tags wtt WHERE wtt.task_id = work_tasks.id)
  OR EXISTS (
    SELECT 1 FROM work_task_tags wtt
    WHERE wtt.task_id = work_tasks.id
      AND wtt.tag_id IN ($placeholders)
  )
)
''');
      whereArgs.addAll(tagIds);
    }

    final results = await db.query(
      'work_tasks',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return results.map(WorkTask.fromMap).toList();
  }

  @override
  Future<void> updateTask(WorkTask task) async {
    final id = task.id;
    if (id == null) {
      throw ArgumentError('updateTask 需要 task.id');
    }
    final db = await _database;
    await db.update(
      'work_tasks',
      task.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteTask(int id) async {
    final db = await _database;
    await db.delete('work_tasks', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> getTotalMinutesForTask(int taskId) async {
    final db = await _database;
    final results = await db.rawQuery(
      'SELECT COALESCE(SUM(minutes), 0) AS total FROM work_time_entries WHERE task_id = ?',
      [taskId],
    );
    return (results.first['total'] as int?) ?? 0;
  }

  @override
  Future<int> createTimeEntry(WorkTimeEntry entry) async {
    final db = await _database;
    return db.insert('work_time_entries', entry.toMap(includeId: false));
  }

  @override
  Future<List<WorkTimeEntry>> listTimeEntriesForTask(
    int taskId, {
    int? limit,
    int? offset,
  }) async {
    final db = await _database;
    final results = await db.query(
      'work_time_entries',
      where: 'task_id = ?',
      whereArgs: [taskId],
      orderBy: 'work_date DESC, created_at DESC',
      limit: limit,
      offset: offset,
    );
    return results.map(WorkTimeEntry.fromMap).toList();
  }

  @override
  Future<List<WorkTimeEntry>> listTimeEntriesInRange(
    DateTime startInclusive,
    DateTime endExclusive,
  ) async {
    final db = await _database;
    final start = _startOfDay(startInclusive).millisecondsSinceEpoch;
    final end = _startOfDay(endExclusive).millisecondsSinceEpoch;
    final results = await db.query(
      'work_time_entries',
      where: 'work_date >= ? AND work_date < ?',
      whereArgs: [start, end],
      orderBy: 'work_date ASC, created_at ASC',
    );
    return results.map(WorkTimeEntry.fromMap).toList();
  }

  @override
  Future<int> getTotalMinutesForDate(DateTime date) async {
    final db = await _database;
    final day = _startOfDay(date).millisecondsSinceEpoch;
    final results = await db.rawQuery(
      'SELECT COALESCE(SUM(minutes), 0) AS total FROM work_time_entries WHERE work_date = ?',
      [day],
    );
    return (results.first['total'] as int?) ?? 0;
  }

  @override
  Future<WorkTimeEntry?> getTimeEntry(int id) async {
    final db = await _database;
    final results = await db.query(
      'work_time_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return WorkTimeEntry.fromMap(results.first);
  }

  @override
  Future<void> updateTimeEntry(WorkTimeEntry entry) async {
    final id = entry.id;
    if (id == null) {
      throw ArgumentError('updateTimeEntry 需要 entry.id');
    }
    final db = await _database;
    await db.update(
      'work_time_entries',
      entry.toMap(includeId: false),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deleteTimeEntry(int id) async {
    final db = await _database;
    await db.delete('work_time_entries', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<int> createOperationLog(OperationLog log) async {
    final db = await _database;
    return db.insert('operation_logs', log.toMap(includeId: false));
  }

  @override
  Future<List<OperationLog>> listOperationLogs({
    int? limit,
    int? offset,
    TargetType? targetType,
    int? targetId,
  }) async {
    final db = await _database;

    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    if (targetType != null) {
      whereParts.add('target_type = ?');
      whereArgs.add(targetType.value);
    }
    if (targetId != null) {
      whereParts.add('target_id = ?');
      whereArgs.add(targetId);
    }

    final results = await db.query(
      'operation_logs',
      where: whereParts.isEmpty ? null : whereParts.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return results.map(OperationLog.fromMap).toList();
  }

  @override
  Future<int> getOperationLogCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM operation_logs',
    );
    return (result.first['count'] as int?) ?? 0;
  }

  @override
  Future<void> importTasksFromServer(
    List<Map<String, dynamic>> tasksData,
  ) async {
    final db = await _database;

    await db.transaction((txn) async {
      // 1. 清空现有任务（级联删除会自动删除关联的time_entries）
      await txn.delete('work_tasks');

      // 2. 批量插入服务端任务
      for (final taskMap in tasksData) {
        await txn.insert('work_tasks', taskMap);
      }
    });
  }

  @override
  Future<void> importTimeEntriesFromServer(
    List<Map<String, dynamic>> entriesData,
  ) async {
    final db = await _database;

    await db.transaction((txn) async {
      // 1. 清空现有工时记录
      await txn.delete('work_time_entries');

      // 2. 批量插入服务端工时记录
      for (final entryMap in entriesData) {
        await txn.insert('work_time_entries', entryMap);
      }
    });
  }

  @override
  Future<void> importOperationLogsFromServer(
    List<Map<String, dynamic>> logsData,
  ) async {
    final db = await _database;

    await db.transaction((txn) async {
      // 1. 清空现有操作日志
      await txn.delete('operation_logs');

      // 2. 批量插入服务端操作日志
      for (final logMap in logsData) {
        await txn.insert('operation_logs', logMap);
      }
    });
  }

  static DateTime _startOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }
}
