import '../models/work_task.dart';

class WorkTaskSortController {
  List<WorkTask> _pinned;
  List<WorkTask> _unpinned;

  WorkTaskSortController._(this._pinned, this._unpinned);

  factory WorkTaskSortController.fromTasks(List<WorkTask> tasks) {
    final pinned = <WorkTask>[];
    final unpinned = <WorkTask>[];
    for (final task in tasks) {
      if (task.isPinned) {
        pinned.add(task);
      } else {
        unpinned.add(task);
      }
    }
    return WorkTaskSortController._(pinned, unpinned);
  }

  List<WorkTask> get pinned => List.unmodifiable(_pinned);
  List<WorkTask> get unpinned => List.unmodifiable(_unpinned);

  List<WorkTask> get all => [..._pinned, ..._unpinned];

  void reorderPinned(int oldIndex, int newIndex) {
    _pinned = _reorder(_pinned, oldIndex, newIndex);
  }

  void reorderUnpinned(int oldIndex, int newIndex) {
    _unpinned = _reorder(_unpinned, oldIndex, newIndex);
  }

  void togglePin(int taskId) {
    final pinnedIndex = _pinned.indexWhere((t) => t.id == taskId);
    if (pinnedIndex >= 0) {
      final task = _pinned.removeAt(pinnedIndex);
      _unpinned.insert(0, task.copyWith(isPinned: false));
      return;
    }

    final unpinnedIndex = _unpinned.indexWhere((t) => t.id == taskId);
    if (unpinnedIndex >= 0) {
      final task = _unpinned.removeAt(unpinnedIndex);
      _pinned.insert(0, task.copyWith(isPinned: true));
    }
  }

  List<WorkTaskSortOrder> buildSortOrders() {
    final orders = <WorkTaskSortOrder>[];
    for (int i = 0; i < _pinned.length; i++) {
      final id = _pinned[i].id;
      if (id == null) continue;
      orders.add(WorkTaskSortOrder(taskId: id, isPinned: true, sortIndex: i));
    }
    for (int i = 0; i < _unpinned.length; i++) {
      final id = _unpinned[i].id;
      if (id == null) continue;
      orders.add(WorkTaskSortOrder(taskId: id, isPinned: false, sortIndex: i));
    }
    return orders;
  }

  static List<WorkTask> _reorder(
    List<WorkTask> list,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) newIndex--;
    final next = [...list];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    return next;
  }
}

