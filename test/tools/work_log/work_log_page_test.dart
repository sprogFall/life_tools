import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';
import 'package:life_tools/tools/work_log/models/work_time_entry.dart';
import 'package:life_tools/tools/work_log/pages/work_log_tool_page.dart';
import 'package:life_tools/tools/work_log/repository/work_log_repository_base.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../test_helpers/fake_work_log_repository.dart';
import '../../test_helpers/test_app_wrapper.dart';

void main() {
  group('WorkLogToolPage', () {
    late WorkLogRepositoryBase repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = FakeWorkLogRepository();
    });

    testWidgets('应该展示标题与分段切换', (tester) async {
      await tester.pumpWidget(
        TestAppWrapper(child: WorkLogToolPage(repository: repository)),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('工作记录'), findsOneWidget);
      expect(find.text('任务'), findsOneWidget);
      expect(find.text('日历'), findsOneWidget);
    });

    testWidgets('默认应展示任务列表页入口', (tester) async {
      await tester.pumpWidget(
        TestAppWrapper(child: WorkLogToolPage(repository: repository)),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byIcon(CupertinoIcons.add), findsOneWidget);
    });

    testWidgets('日历页点击右上角加号也应进入创建任务页', (tester) async {
      await tester.pumpWidget(
        TestAppWrapper(child: WorkLogToolPage(repository: repository)),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.drag(find.byType(PageView), const Offset(-600, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // 日历页面不展示语音录入按钮，用于确认当前已切换到日历 tab
      expect(
        find.byKey(const ValueKey('work_log_ai_input_button')),
        findsNothing,
      );

      await tester.tap(find.byIcon(CupertinoIcons.add));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('创建任务'), findsOneWidget);
    });

    testWidgets('应该可以创建任务并在列表中显示', (tester) async {
      await tester.pumpWidget(
        TestAppWrapper(child: WorkLogToolPage(repository: repository)),
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
        TestAppWrapper(child: WorkLogToolPage(repository: repository)),
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
      final fake = FakeWorkLogRepository();
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
        TestAppWrapper(child: WorkLogToolPage(repository: fake)),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('日历'));
      await tester.pumpAndSettle();

      expect(find.text('月'), findsOneWidget);
      expect(find.text('周'), findsOneWidget);
      expect(find.text('日'), findsWidgets);

      expect(find.text('1.5h'), findsWidgets);
    });

    testWidgets('日历日视图工时卡片应以工作内容为主并显示字段名', (tester) async {
      final fake = FakeWorkLogRepository();
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
        TestAppWrapper(child: WorkLogToolPage(repository: fake)),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('日历'));
      await tester.pumpAndSettle();

      // 点击月视图中包含工时汇总的日期格子，进入日视图
      await tester.tap(find.text('1.5h').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('工作内容：开发功能A'), findsOneWidget);
      expect(find.text('任务：任务A'), findsOneWidget);
    });

    testWidgets('日历月视图应展示选中日期信息与近期记录卡片', (tester) async {
      final fake = FakeWorkLogRepository();
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

      final today = DateTime.now();
      final anotherDay = DateTime(today.year, today.month, 1);

      await fake.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: today,
          minutes: 60,
          content: '今日记录',
          now: DateTime(2026, 1, 1),
        ),
      );
      await fake.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: anotherDay,
          minutes: 120,
          content: '近期记录',
          now: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(
        TestAppWrapper(child: WorkLogToolPage(repository: fake)),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('日历'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('work_log_calendar_selected_day_card')),
        findsOneWidget,
      );
      expect(find.text('当天记录'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('work_log_calendar_recent_days_card')),
        findsOneWidget,
      );
      expect(find.text('近期记录'), findsWidgets);
    });

    testWidgets('日历月视图点击日期后应保持月网格并刷新选中工时', (tester) async {
      final fake = FakeWorkLogRepository();
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

      final now = DateTime.now();
      final targetDate = DateTime(
        now.year,
        now.month,
        now.day > 1 ? now.day - 1 : now.day + 1,
      );
      final targetKey = ValueKey(
        'work_log_calendar_day_cell_${targetDate.year}${targetDate.month.toString().padLeft(2, '0')}${targetDate.day.toString().padLeft(2, '0')}',
      );

      await fake.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: now,
          minutes: 60,
          content: '今日记录',
          now: DateTime(2026, 1, 1),
        ),
      );
      await fake.createTimeEntry(
        WorkTimeEntry.create(
          taskId: taskId,
          workDate: targetDate,
          minutes: 120,
          content: '目标记录',
          now: DateTime(2026, 1, 1),
        ),
      );

      await tester.pumpWidget(
        TestAppWrapper(child: WorkLogToolPage(repository: fake)),
      );
      await tester.pump(const Duration(milliseconds: 600));

      await tester.tap(find.text('日历'));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.byKey(targetKey), findsOneWidget);
      expect(find.text('1h'), findsWidgets);

      await tester.tap(find.byKey(targetKey));
      await tester.pumpAndSettle();

      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('2h'), findsWidgets);
    });
  });
}
