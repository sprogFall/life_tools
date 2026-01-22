import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/pages/work_log_tool_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/fake_work_log_repository.dart';

void main() {
  group('WorkTaskListView 置顶标记', () {
    testWidgets('置顶任务应展示置顶标记，未置顶不展示', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeWorkLogRepository();

      final pinnedId = await repo.createTask(
        WorkTask.create(
          title: '置顶任务',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1, 9),
        ).copyWith(isPinned: true, sortIndex: 0),
      );
      final normalId = await repo.createTask(
        WorkTask.create(
          title: '普通任务',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1, 10),
        ).copyWith(isPinned: false, sortIndex: 0),
      );

      await tester.pumpWidget(
        MaterialApp(home: WorkLogToolPage(repository: repo)),
      );
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('置顶任务'), findsOneWidget);
      expect(find.text('普通任务'), findsOneWidget);

      expect(
        find.byKey(ValueKey('task-pinned-corner-$pinnedId')),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey('task-pinned-badge-$normalId')), findsNothing);
    });
  });
}
