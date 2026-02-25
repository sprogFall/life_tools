import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/tags/tag_repository.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/work_log/services/work_log_service.dart';
import 'package:life_tools/tools/work_log/sync/work_log_sync_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../test_helpers/fake_work_log_repository.dart';

class _FakeDatabase extends Fake implements Database {}

WorkTask _buildTask(int id) {
  final now = DateTime(2026, 1, 1, 10);
  return WorkTask.create(
    title: '任务$id',
    description: '',
    startAt: null,
    endAt: null,
    status: WorkTaskStatus.todo,
    estimatedMinutes: 60,
    now: now,
  ).copyWith(id: id);
}

class _BlockingMinutesRepository extends FakeWorkLogRepository {
  final List<WorkTask> seededTasks;
  final List<int> requestedTaskIds = <int>[];
  late final Map<int, Completer<int>> _minuteCompleters;

  _BlockingMinutesRepository({required this.seededTasks}) {
    _minuteCompleters = {
      for (final task in seededTasks)
        if (task.id != null) task.id!: Completer<int>(),
    };
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
    var list = List<WorkTask>.from(seededTasks);
    if (offset != null && offset > 0) {
      list = list.skip(offset).toList();
    }
    if (limit != null && limit > 0) {
      list = list.take(limit).toList();
    }
    return list;
  }

  @override
  Future<int> getTotalMinutesForTask(int taskId) {
    requestedTaskIds.add(taskId);
    return _minuteCompleters.putIfAbsent(taskId, () => Completer<int>()).future;
  }

  void completeAllMinutes(int value) {
    for (final completer in _minuteCompleters.values) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }
  }
}

class _BlockingExportRepository extends FakeWorkLogRepository {
  final List<WorkTask> seededTasks;
  final List<int> requestedTaskIds = <int>[];
  late final Map<int, Completer<List<WorkTimeEntry>>> _entryCompleters;

  _BlockingExportRepository({required this.seededTasks}) {
    _entryCompleters = {
      for (final task in seededTasks)
        if (task.id != null) task.id!: Completer<List<WorkTimeEntry>>(),
    };
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
    return List<WorkTask>.from(seededTasks);
  }

  @override
  Future<List<WorkTimeEntry>> listTimeEntriesForTask(
    int taskId, {
    int? limit,
    int? offset,
  }) {
    requestedTaskIds.add(taskId);
    return _entryCompleters
        .putIfAbsent(taskId, () => Completer<List<WorkTimeEntry>>())
        .future;
  }

  void completeAllEntries() {
    for (final entry in _entryCompleters.entries) {
      final completer = entry.value;
      if (completer.isCompleted) continue;
      final taskId = entry.key;
      completer.complete([
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime(2026, 1, 2),
          minutes: 30,
          content: '记录$taskId',
          now: DateTime(2026, 1, 2, 10),
        ).copyWith(id: taskId),
      ]);
    }
  }
}

class _StubTagRepository extends TagRepository {
  _StubTagRepository() : super.withDatabase(_FakeDatabase());

  @override
  Future<List<Map<String, Object?>>> exportWorkTaskTags() async {
    return const [];
  }

  @override
  Future<void> importWorkTaskTagsFromServer(
    List<Map<String, dynamic>> rows,
  ) async {}
}

Future<void> _pumpMicrotasks() async {
  for (int i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('WorkLog 异步加载性能（并行化）', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('WorkLogService.loadTasks 应并行触发任务耗时查询', () async {
      final repo = _BlockingMinutesRepository(
        seededTasks: [_buildTask(1), _buildTask(2), _buildTask(3)],
      );
      final service = WorkLogService(repository: repo);

      final loading = service.loadTasks();
      await _pumpMicrotasks();

      expect(repo.requestedTaskIds, containsAll([1, 2, 3]));
      expect(repo.requestedTaskIds.length, 3);

      repo.completeAllMinutes(0);
      await loading;
    });

    test('WorkLogSyncProvider.exportData 应并行触发多任务工时导出', () async {
      final repo = _BlockingExportRepository(
        seededTasks: [_buildTask(11), _buildTask(12), _buildTask(13)],
      );
      final provider = WorkLogSyncProvider(
        repository: repo,
        tagRepository: _StubTagRepository(),
      );

      final exporting = provider.exportData();
      await _pumpMicrotasks();

      expect(repo.requestedTaskIds, containsAll([11, 12, 13]));
      expect(repo.requestedTaskIds.length, 3);

      repo.completeAllEntries();
      final exported = await exporting;
      final data = exported['data'] as Map<String, dynamic>;
      final timeEntries = data['time_entries'] as List<dynamic>;
      expect(timeEntries.length, 3);
    });
  });
}
