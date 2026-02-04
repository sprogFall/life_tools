import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/pages/work_log_tool_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../test_helpers/fake_work_log_repository.dart';
import '../../test_helpers/test_app_wrapper.dart';

void main() {
  group('WorkTaskSortPage', () {
    Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
      for (int i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (finder.evaluate().isNotEmpty) return;
      }
      fail('等待组件超时: $finder');
    }

    Future<void> pumpUntilNotFound(WidgetTester tester, Finder finder) async {
      for (int i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (finder.evaluate().isEmpty) return;
      }
      fail('等待组件消失超时: $finder');
    }

    testWidgets('进入排序页后可置顶并保存生效', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = FakeWorkLogRepository();

      final idA = await repo.createTask(
        WorkTask.create(
          title: '任务A',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1, 8),
        ),
      );
      final idB = await repo.createTask(
        WorkTask.create(
          title: '任务B',
          description: '',
          startAt: null,
          endAt: null,
          status: WorkTaskStatus.todo,
          estimatedMinutes: 0,
          now: DateTime(2026, 1, 1, 9),
        ),
      );

      await tester.pumpWidget(
        TestAppWrapper(child: WorkLogToolPage(repository: repo)),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.byKey(const ValueKey('work_log_sort_button')));
      await tester.pump();
      await pumpUntilFound(tester, find.text('排序任务'));
      await tester.pump(const Duration(milliseconds: 800));

      // 置顶任务B
      await tester.tap(find.byKey(ValueKey('task-pin-$idB')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('置顶'), findsOneWidget);

      final posBInSort = tester
          .getTopLeft(find.byKey(ValueKey('work-task-sort-row-$idB')))
          .dy;
      final posAInSort = tester
          .getTopLeft(find.byKey(ValueKey('work-task-sort-row-$idA')))
          .dy;
      expect(posBInSort, lessThan(posAInSort));

      // 保存并返回列表
      await tester.tap(
        find.byKey(const ValueKey('work_task_sort_save_button')),
      );
      await tester.pump();
      await pumpUntilNotFound(tester, find.text('排序任务'));

      final posBInList = tester.getTopLeft(find.text('任务B').first).dy;
      final posAInList = tester.getTopLeft(find.text('任务A').first).dy;
      expect(posBInList, lessThan(posAInList));

      // 确保排序页已退出
      expect(find.byKey(ValueKey('task-pin-$idA')), findsNothing);
    });
  });
}
