import 'package:flutter_test/flutter_test.dart';
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
      );

      final restored = WorkTimeEntry.fromMap(entry.toMap());

      expect(restored.id, entry.id);
      expect(restored.taskId, entry.taskId);
      expect(restored.workDate, entry.workDate);
      expect(restored.minutes, entry.minutes);
      expect(restored.content, entry.content);
      expect(restored.createdAt, entry.createdAt);
    });
  });
}

