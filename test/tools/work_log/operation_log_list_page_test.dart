import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/pages/log/operation_log_list_page.dart';
import 'package:life_tools/tools/work_log/services/work_log_service.dart';
import 'package:provider/provider.dart';

import '../../test_helpers/fake_work_log_repository.dart';
import '../../test_helpers/test_app_wrapper.dart';

void main() {
  group('OperationLogListPage', () {
    testWidgets('应展示最近10次操作提示', (tester) async {
      final repository = FakeWorkLogRepository();
      final service = WorkLogService(repository: repository);
      addTearDown(service.dispose);

      await tester.pumpWidget(
        TestAppWrapper(
          child: ChangeNotifierProvider.value(
            value: service,
            child: const OperationLogListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('仅可查看最近10次操作'), findsOneWidget);
      expect(find.text('暂无操作记录'), findsOneWidget);
    });

    testWidgets('应支持调整操作日志保留条数', (tester) async {
      final repository = FakeWorkLogRepository();
      final service = WorkLogService(repository: repository);
      addTearDown(service.dispose);

      await tester.pumpWidget(
        TestAppWrapper(
          child: ChangeNotifierProvider.value(
            value: service,
            child: const OperationLogListPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('work_log_operation_logs_limit_button')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('20 条'));
      await tester.pumpAndSettle();

      expect(find.text('仅可查看最近20次操作'), findsOneWidget);
    });
  });
}
