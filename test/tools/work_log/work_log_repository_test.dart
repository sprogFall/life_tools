import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/database/database_schema.dart';
import 'package:life_tools/tools/work_log/models/operation_log.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('WorkLogRepository', () {
    late WorkLogRepository repository;
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: DatabaseSchema.version,
        onConfigure: DatabaseSchema.onConfigure,
        onCreate: DatabaseSchema.onCreate,
        onUpgrade: DatabaseSchema.onUpgrade,
      );
      repository = WorkLogRepository.withDatabase(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('应该可以创建并读取任务', () async {
      final now = DateTime(2026, 1, 1, 8);
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '描述A',
          startAt: DateTime(2026, 1, 1, 9),
          endAt: DateTime(2026, 1, 3, 18),
          status: WorkTaskStatus.todo,
          estimatedMinutes: 60,
          now: now,
        ),
      );

      final task = await repository.getTask(taskId);
      expect(task, isNotNull);
      expect(task!.title, '任务A');
      expect(task.status, WorkTaskStatus.todo);
      expect(task.createdAt, now);
    });

    test('应该可以更新任务状态与预计工时', () async {
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );

      final task = (await repository.getTask(taskId))!;
      final updated = task.copyWith(
        status: WorkTaskStatus.done,
        estimatedMinutes: 120,
        updatedAt: DateTime(2026, 1, 2),
      );
      await repository.updateTask(updated);

      final again = (await repository.getTask(taskId))!;
      expect(again.status, WorkTaskStatus.done);
      expect(again.estimatedMinutes, 120);
      expect(again.updatedAt, DateTime(2026, 1, 2));
    });

    test('应该可以在任务下添加工时并按日期汇总', () async {
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );

      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 1, 2),
          minutes: 30,
          content: 'A-1',
          now: DateTime(2026, 1, 2, 9),
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 1, 2),
          minutes: 45,
          content: 'A-2',
          now: DateTime(2026, 1, 2, 18),
        ),
      );

      final minutes = await repository.getTotalMinutesForDate(
        DateTime(2026, 1, 2),
      );
      expect(minutes, 75);
    });

    test('应该可以按时间范围查询工时记录', () async {
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );

      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 1, 2),
          minutes: 30,
          content: 'A-1',
          now: DateTime(2026, 1, 2, 9),
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 1, 3),
          minutes: 60,
          content: 'A-2',
          now: DateTime(2026, 1, 3, 9),
        ),
      );

      final entries = await repository.listTimeEntriesInRange(
        DateTime(2026, 1, 2),
        DateTime(2026, 1, 4),
      );
      expect(entries.length, 2);
      expect(entries.map((e) => e.workDate), contains(DateTime(2026, 1, 2)));
      expect(entries.map((e) => e.workDate), contains(DateTime(2026, 1, 3)));
    });

    test('应该可以更新工时记录', () async {
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );

      final entryId = await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 1, 2),
          minutes: 30,
          content: '初始内容',
          now: DateTime(2026, 1, 2, 9),
        ),
      );

      final entry = await repository.getTimeEntry(entryId);
      expect(entry, isNotNull);

      final updated = entry!.copyWith(
        minutes: 60,
        content: '更新后的内容',
        updatedAt: DateTime(2026, 1, 2, 10),
      );
      await repository.updateTimeEntry(updated);

      final again = await repository.getTimeEntry(entryId);
      expect(again!.minutes, 60);
      expect(again.content, '更新后的内容');
    });

    test('应该可以删除工时记录', () async {
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );

      final entryId = await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 1, 2),
          minutes: 30,
          content: '待删除',
          now: DateTime(2026, 1, 2, 9),
        ),
      );

      await repository.deleteTimeEntry(entryId);

      final entry = await repository.getTimeEntry(entryId);
      expect(entry, isNull);
    });

    test('应该可以创建和查询操作日志', () async {
      await repository.createOperationLog(
        OperationLog.create(
          operationType: OperationType.createTask,
          targetType: TargetType.task,
          targetId: 1,
          targetTitle: '任务A',
          summary: '创建任务「任务A」',
          now: DateTime(2026, 1, 1, 10),
        ),
      );

      await repository.createOperationLog(
        OperationLog.create(
          operationType: OperationType.updateTask,
          targetType: TargetType.task,
          targetId: 1,
          targetTitle: '任务A',
          summary: '状态: 待办 -> 进行中',
          now: DateTime(2026, 1, 1, 11),
        ),
      );

      final logs = await repository.listOperationLogs(limit: 10);
      expect(logs.length, 2);
      // 按时间倒序
      expect(logs.first.operationType, OperationType.updateTask);
      expect(logs.last.operationType, OperationType.createTask);

      final count = await repository.getOperationLogCount();
      expect(count, 2);
    });

    test('应该可以按目标类型过滤操作日志', () async {
      await repository.createOperationLog(
        OperationLog.create(
          operationType: OperationType.createTask,
          targetType: TargetType.task,
          targetId: 1,
          targetTitle: '任务A',
          summary: '创建任务',
          now: DateTime(2026, 1, 1, 10),
        ),
      );

      await repository.createOperationLog(
        OperationLog.create(
          operationType: OperationType.createTimeEntry,
          targetType: TargetType.timeEntry,
          targetId: 1,
          targetTitle: '工时记录',
          summary: '创建工时',
          now: DateTime(2026, 1, 1, 11),
        ),
      );

      final taskLogs = await repository.listOperationLogs(
        targetType: TargetType.task,
      );
      expect(taskLogs.length, 1);
      expect(taskLogs.first.operationType, OperationType.createTask);

      final entryLogs = await repository.listOperationLogs(
        targetType: TargetType.timeEntry,
      );
      expect(entryLogs.length, 1);
      expect(entryLogs.first.operationType, OperationType.createTimeEntry);
    });

    test('应该按创建时间倒序排列任务列表', () async {
      await repository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1, 9),
        ),
      );
      await repository.createTask(
        WorkTask.create(
          title: '任务B',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1, 10),
        ),
      );
      await repository.createTask(
        WorkTask.create(
          title: '任务C',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1, 11),
        ),
      );

      final tasks = await repository.listTasks();
      expect(tasks.length, 3);
      expect(tasks[0].title, '任务C');
      expect(tasks[1].title, '任务B');
      expect(tasks[2].title, '任务A');
    });

    test('应该支持多状态筛选任务', () async {
      await repository.createTask(
        WorkTask.create(
          title: '待办任务',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );
      await repository.createTask(
        WorkTask.create(
          title: '进行中任务',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );
      await repository.createTask(
        WorkTask.create(
          title: '已完成任务',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.done,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );
      await repository.createTask(
        WorkTask.create(
          title: '已取消任务',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.canceled,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );

      final todoAndDoing = await repository.listTasks(
        statuses: [WorkTaskStatus.todo, WorkTaskStatus.doing],
      );
      expect(todoAndDoing.length, 2);
      expect(todoAndDoing.map((t) => t.status), contains(WorkTaskStatus.todo));
      expect(todoAndDoing.map((t) => t.status), contains(WorkTaskStatus.doing));

      final doneOnly = await repository.listTasks(
        statuses: [WorkTaskStatus.done],
      );
      expect(doneOnly.length, 1);
      expect(doneOnly.first.status, WorkTaskStatus.done);
    });

    test('应该能计算任务的总工时', () async {
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 120,
          now: DateTime(2026, 1, 1),
        ),
      );

      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 1, 2),
          minutes: 30,
          content: 'A-1',
          now: DateTime(2026, 1, 2, 9),
        ),
      );
      await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 1, 3),
          minutes: 45,
          content: 'A-2',
          now: DateTime(2026, 1, 3, 9),
        ),
      );

      final totalMinutes = await repository.getTotalMinutesForTask(taskId);
      expect(totalMinutes, 75);
    });

    test('删除任务应级联删除工时记录但保留操作日志', () async {
      final taskId = await repository.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.doing,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1),
        ),
      );

      final entryId = await repository.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 1, 2),
          minutes: 30,
          content: 'A-1',
          now: DateTime(2026, 1, 2, 9),
        ),
      );

      await repository.createOperationLog(
        OperationLog.create(
          operationType: OperationType.createTask,
          targetType: TargetType.task,
          targetId: taskId,
          targetTitle: '任务A',
          summary: '创建任务',
          now: DateTime(2026, 1, 1),
        ),
      );

      await repository.deleteTask(taskId);

      final task = await repository.getTask(taskId);
      expect(task, isNull);

      final entry = await repository.getTimeEntry(entryId);
      expect(entry, isNull);

      final logs = await repository.listOperationLogs();
      expect(logs.length, 1);
    });
  });
}
