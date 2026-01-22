import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/services/work_task_sort_controller.dart';

void main() {
  group('WorkTaskSortController', () {
    WorkTask task(
      int id,
      String title, {
      bool isPinned = false,
      int sortIndex = 0,
    }) {
      return WorkTask(
        id: id,
        title: title,
        description: '',
        startAt: null,
        endAt: null,
        status: WorkTaskStatus.todo,
        estimatedMinutes: 0,
        isPinned: isPinned,
        sortIndex: sortIndex,
        createdAt: DateTime(2026, 1, 1, 8).add(Duration(minutes: id)),
        updatedAt: DateTime(2026, 1, 1, 8).add(Duration(minutes: id)),
      );
    }

    test('初始化时应按置顶拆分为两组，并保持组内顺序', () {
      final controller = WorkTaskSortController.fromTasks([
        task(1, 'A', isPinned: true),
        task(2, 'B'),
        task(3, 'C', isPinned: true),
        task(4, 'D'),
      ]);

      expect(controller.pinned.map((t) => t.id), [1, 3]);
      expect(controller.unpinned.map((t) => t.id), [2, 4]);
    });

    test('置顶操作应把任务移动到置顶组顶部', () {
      final controller = WorkTaskSortController.fromTasks([
        task(1, 'A'),
        task(2, 'B'),
        task(3, 'C', isPinned: true),
      ]);

      controller.togglePin(2);

      expect(controller.pinned.map((t) => t.id), [2, 3]);
      expect(controller.unpinned.map((t) => t.id), [1]);
      expect(controller.pinned.first.isPinned, isTrue);
    });

    test('取消置顶应把任务移动到未置顶组顶部', () {
      final controller = WorkTaskSortController.fromTasks([
        task(1, 'A', isPinned: true),
        task(2, 'B'),
        task(3, 'C', isPinned: true),
      ]);

      controller.togglePin(3);

      expect(controller.pinned.map((t) => t.id), [1]);
      expect(controller.unpinned.map((t) => t.id), [3, 2]);
      expect(controller.unpinned.first.isPinned, isFalse);
    });

    test('组内拖拽排序应只影响组内顺序', () {
      final controller = WorkTaskSortController.fromTasks([
        task(1, 'A', isPinned: true),
        task(2, 'B', isPinned: true),
        task(3, 'C'),
        task(4, 'D'),
      ]);

      controller.reorderPinned(0, 2);
      controller.reorderUnpinned(1, 0);

      expect(controller.pinned.map((t) => t.id), [2, 1]);
      expect(controller.unpinned.map((t) => t.id), [4, 3]);
    });

    test('buildSortOrders 应生成每组从0开始的连续 sortIndex', () {
      final controller = WorkTaskSortController.fromTasks([
        task(1, 'A', isPinned: true),
        task(2, 'B'),
        task(3, 'C', isPinned: true),
        task(4, 'D'),
      ]);

      final orders = controller.buildSortOrders();
      expect(orders.map((o) => (o.taskId, o.isPinned, o.sortIndex)), [
        (1, true, 0),
        (3, true, 1),
        (2, false, 0),
        (4, false, 1),
      ]);
    });
  });
}
