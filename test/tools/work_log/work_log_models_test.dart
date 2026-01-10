import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/models/operation_log.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';

void main() {
  group('WorkTask', () {
    test('toMap/fromMap 应该可往返', () {
      final task = WorkTask(
        id: 1,
        title: '任务A',
        description: '描述A',
        startAt: DateTime(2026, 1, 1, 9),
        endAt: DateTime(2026, 1, 10, 18),
        status: WorkTaskStatus.doing,
        estimatedMinutes: 8 * 60,
        createdAt: DateTime(2026, 1, 1, 8),
        updatedAt: DateTime(2026, 1, 1, 8, 30),
      );

      final restored = WorkTask.fromMap(task.toMap());

      expect(restored.id, task.id);
      expect(restored.title, task.title);
      expect(restored.description, task.description);
      expect(restored.startAt, task.startAt);
      expect(restored.endAt, task.endAt);
      expect(restored.status, task.status);
      expect(restored.estimatedMinutes, task.estimatedMinutes);
      expect(restored.createdAt, task.createdAt);
      expect(restored.updatedAt, task.updatedAt);
    });
  });

  group('WorkTimeEntry', () {
    test('toMap/fromMap 应该可往返', () {
      final entry = WorkTimeEntry(
        id: 2,
        taskId: 1,
        workDate: DateTime(2026, 1, 2),
        minutes: 90,
        content: '实现创建任务页面',
        createdAt: DateTime(2026, 1, 2, 10, 30),
        updatedAt: DateTime(2026, 1, 2, 11, 0),
      );

      final restored = WorkTimeEntry.fromMap(entry.toMap());

      expect(restored.id, entry.id);
      expect(restored.taskId, entry.taskId);
      expect(restored.workDate, entry.workDate);
      expect(restored.minutes, entry.minutes);
      expect(restored.content, entry.content);
      expect(restored.createdAt, entry.createdAt);
      expect(restored.updatedAt, entry.updatedAt);
    });

    test('updatedAt 默认应该等于 createdAt', () {
      final entry = WorkTimeEntry.create(
        taskId: 1,
        workDate: DateTime(2026, 1, 2),
        minutes: 60,
        content: '测试内容',
        now: DateTime(2026, 1, 2, 10, 0),
      );

      expect(entry.createdAt, entry.updatedAt);
    });
  });

  group('OperationLog', () {
    test('toMap/fromMap 应该可往返', () {
      final log = OperationLog(
        id: 1,
        operationType: OperationType.createTask,
        targetType: TargetType.task,
        targetId: 10,
        targetTitle: '任务A',
        beforeSnapshot: null,
        afterSnapshot: '{"id":10,"title":"任务A"}',
        summary: '创建任务「任务A」',
        createdAt: DateTime(2026, 1, 5, 10, 30),
      );

      final restored = OperationLog.fromMap(log.toMap());

      expect(restored.id, log.id);
      expect(restored.operationType, log.operationType);
      expect(restored.targetType, log.targetType);
      expect(restored.targetId, log.targetId);
      expect(restored.targetTitle, log.targetTitle);
      expect(restored.beforeSnapshot, log.beforeSnapshot);
      expect(restored.afterSnapshot, log.afterSnapshot);
      expect(restored.summary, log.summary);
      expect(restored.createdAt, log.createdAt);
    });

    test('OperationType.displayName 应该返回正确的中文名称', () {
      expect(OperationType.createTask.displayName, '创建任务');
      expect(OperationType.updateTask.displayName, '更新任务');
      expect(OperationType.deleteTask.displayName, '删除任务');
      expect(OperationType.createTimeEntry.displayName, '创建工时');
      expect(OperationType.updateTimeEntry.displayName, '更新工时');
      expect(OperationType.deleteTimeEntry.displayName, '删除工时');
    });

    test('OperationType.fromValue 应该正确解析', () {
      expect(OperationType.fromValue(0), OperationType.createTask);
      expect(OperationType.fromValue(1), OperationType.updateTask);
      expect(OperationType.fromValue(2), OperationType.deleteTask);
      expect(OperationType.fromValue(3), OperationType.createTimeEntry);
      expect(OperationType.fromValue(4), OperationType.updateTimeEntry);
      expect(OperationType.fromValue(5), OperationType.deleteTimeEntry);
    });

    test('TargetType.fromValue 应该正确解析', () {
      expect(TargetType.fromValue(0), TargetType.task);
      expect(TargetType.fromValue(1), TargetType.timeEntry);
    });
  });
}

