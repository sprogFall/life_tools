import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/models/operation_log.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/work_log/pages/work_log_tool_page.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository_base.dart';

void main() {
  group('WorkLogToolPage', () {
    late WorkLogRepositoryBase repository;

    setUp(() {
      repository = _FakeWorkLogRepository();
    });

    testWidgets('应该展示标题与分段切换', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkLogToolPage(repository: repository),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('工作记录'), findsOneWidget);
      expect(find.text('任务'), findsOneWidget);
      expect(find.text('日历'), findsOneWidget);
    });

    testWidgets('默认应展示任务列表页入口', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkLogToolPage(repository: repository),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(CupertinoIcons.add), findsOneWidget);
    });

    testWidgets('应该可以创建任务并在列表中显示', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkLogToolPage(repository: repository),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('创建任务'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('task_title_field')),
        '任务A',
      );
      await tester.enterText(
        find.byKey(const ValueKey('task_description_field')),
        '描述A',
      );
      await tester.enterText(
        find.byKey(const ValueKey('task_estimated_hours_field')),
        '1.5',
      );

      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));

      expect(find.text('任务A'), findsOneWidget);
    });

    testWidgets('应该可以在任务下记录工时并查看', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WorkLogToolPage(repository: repository),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      await tester.enterText(
        find.byKey(const ValueKey('task_title_field')),
        '任务A',
      );
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      await tester.tap(find.text('任务A'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('任务A'), findsWidgets);

      // 点击更多按钮打开操作菜单
      await tester.tap(find.byIcon(CupertinoIcons.ellipsis));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 点击添加工时选项
      await tester.tap(find.text('添加工时'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('记录工时'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('time_entry_minutes_field')),
        '90',
      );
      await tester.enterText(
        find.byKey(const ValueKey('time_entry_content_field')),
        '开发功能A',
      );
      await tester.tap(find.text('保存'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('开发功能A'), findsOneWidget);
    });

    testWidgets('日历月视图应展示当日工时汇总', (tester) async {
      final fake = _FakeWorkLogRepository();
      final taskId = await fake.createTask(
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
      await fake.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime.now(),
          minutes: 90,
          content: '开发功能A',
          now: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WorkLogToolPage(repository: fake),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('日历'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('月'), findsOneWidget);
      expect(find.text('周'), findsOneWidget);
      expect(find.text('日'), findsWidgets);

      expect(find.text('1.5h'), findsWidgets);
    });

    testWidgets('日历日视图工时卡片应以工作内容为主并显示字段名', (tester) async {
      final fake = _FakeWorkLogRepository();
      final taskId = await fake.createTask(
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
      await fake.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: DateTime.now(),
          minutes: 90,
          content: '开发功能A',
          now: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: WorkLogToolPage(repository: fake),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('日历'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // 点击月视图中包含工时汇总的日期格子，进入日视图
      await tester.tap(find.text('1.5h').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('工作内容：开发功能A'), findsOneWidget);
      expect(find.text('任务：任务A'), findsOneWidget);
    });
  });
}

class _FakeWorkLogRepository implements WorkLogRepositoryBase {
  int _taskId = 0;
  int _entryId = 0;
  int _logId = 0;
  final List<WorkTask> _tasks = [];
  final List<WorkTimeEntry> _entries = [];
  final List<OperationLog> _logs = [];

  @override
  Future<int> createTask(WorkTask task) async {
    final id = ++_taskId;
    _tasks.add(task.copyWith(id: id));
    return id;
  }

  @override
  Future<void> deleteTask(int id) async {
    _tasks.removeWhere((t) => t.id == id);
  }

  @override
  Future<WorkTask?> getTask(int id) async {
    for (final t in _tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  @override
  Future<List<WorkTask>> listTasks({
    WorkTaskStatus? status,
    String? keyword,
  }) async {
    Iterable<WorkTask> result = _tasks;
    if (status != null) {
      result = result.where((t) => t.status == status);
    }
    if (keyword != null && keyword.trim().isNotEmpty) {
      final lower = keyword.trim().toLowerCase();
      result = result.where(
        (t) =>
            t.title.toLowerCase().contains(lower) ||
            t.description.toLowerCase().contains(lower),
      );
    }
    return result.toList();
  }

  @override
  Future<void> updateTask(WorkTask task) async {
    final id = task.id;
    if (id == null) return;
    final index = _tasks.indexWhere((t) => t.id == id);
    if (index >= 0) _tasks[index] = task;
  }

  @override
  Future<int> createTimeEntry(WorkTimeEntry entry) async {
    final id = ++_entryId;
    _entries.add(entry.copyWith(id: id));
    return id;
  }

  @override
  Future<WorkTimeEntry?> getTimeEntry(int id) async {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  @override
  Future<void> updateTimeEntry(WorkTimeEntry entry) async {
    final id = entry.id;
    if (id == null) return;
    final index = _entries.indexWhere((e) => e.id == id);
    if (index >= 0) _entries[index] = entry;
  }

  @override
  Future<void> deleteTimeEntry(int id) async {
    _entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<int> getTotalMinutesForDate(DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    return _entries
        .where((e) => e.workDate == day)
        .fold<int>(0, (sum, e) => sum + e.minutes);
  }

  @override
  Future<List<WorkTimeEntry>> listTimeEntriesForTask(int taskId) async {
    return _entries.where((e) => e.taskId == taskId).toList();
  }

  @override
  Future<List<WorkTimeEntry>> listTimeEntriesInRange(
    DateTime startInclusive,
    DateTime endExclusive,
  ) async {
    final start = DateTime(startInclusive.year, startInclusive.month, startInclusive.day);
    final end = DateTime(endExclusive.year, endExclusive.month, endExclusive.day);
    return _entries
        .where((e) => !e.workDate.isBefore(start) && e.workDate.isBefore(end))
        .toList();
  }

  @override
  Future<int> createOperationLog(OperationLog log) async {
    final id = ++_logId;
    _logs.add(OperationLog(
      id: id,
      operationType: log.operationType,
      targetType: log.targetType,
      targetId: log.targetId,
      targetTitle: log.targetTitle,
      beforeSnapshot: log.beforeSnapshot,
      afterSnapshot: log.afterSnapshot,
      summary: log.summary,
      createdAt: log.createdAt,
    ));
    return id;
  }

  @override
  Future<List<OperationLog>> listOperationLogs({
    int? limit,
    int? offset,
    TargetType? targetType,
    int? targetId,
  }) async {
    Iterable<OperationLog> result = _logs;
    if (targetType != null) {
      result = result.where((l) => l.targetType == targetType);
    }
    if (targetId != null) {
      result = result.where((l) => l.targetId == targetId);
    }
    var list = result.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (offset != null && offset > 0) {
      list = list.skip(offset).toList();
    }
    if (limit != null && limit > 0) {
      list = list.take(limit).toList();
    }
    return list;
  }

  @override
  Future<int> getOperationLogCount() async {
    return _logs.length;
  }
}
