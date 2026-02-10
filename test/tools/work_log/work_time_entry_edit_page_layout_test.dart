import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';
import 'package:life_tools/tools/work_log/pages/time/work_time_entry_edit_page.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  testWidgets('短任务名称下关联任务卡片仍占满可用宽度', (tester) async {
    await tester.pumpWidget(
      const TestAppWrapper(
        child: WorkTimeEntryEditPage(taskId: 1, taskTitle: '短任务'),
      ),
    );
    await tester.pumpAndSettle();

    final cardFinder = find.ancestor(
      of: find.text('关联任务'),
      matching: find.byType(GlassContainer),
    );

    expect(cardFinder, findsOneWidget);

    final scaffoldWidth = tester.getSize(find.byType(Scaffold)).width;
    final cardWidth = tester.getSize(cardFinder).width;

    expect(cardWidth, closeTo(scaffoldWidth - 40, 0.1));
  });
}
