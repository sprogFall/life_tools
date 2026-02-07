import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/pages/calendar/work_log_calendar_view.dart';
import 'package:life_tools/tools/work_log/services/work_log_service.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/fake_work_log_repository.dart';
import '../../test_helpers/test_app_wrapper.dart';

void main() {
  testWidgets('月视图日期格应展示液态玻璃立体层次', (tester) async {
    final service = WorkLogService(repository: FakeWorkLogRepository());
    addTearDown(service.dispose);

    await tester.pumpWidget(
      TestAppWrapper(
        child: ChangeNotifierProvider.value(
          value: service,
          child: const CupertinoPageScaffold(child: WorkLogCalendarView()),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));

    final containers = tester.widgetList<Container>(find.byType(Container));
    final hasThreeDimensionalDayCell = containers.any((container) {
      final decoration = container.decoration;
      if (decoration is! BoxDecoration) return false;
      final hasGradient = decoration.gradient != null;
      final hasLayeredShadow = (decoration.boxShadow?.length ?? 0) >= 2;
      final hasRoundedCorner = decoration.borderRadius != null;
      return hasGradient && hasLayeredShadow && hasRoundedCorner;
    });

    expect(hasThreeDimensionalDayCell, isTrue);
  });
}
