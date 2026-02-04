import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/l10n/app_localizations.dart';
import 'package:life_tools/tools/work_log/pages/work_log_tool_page.dart';

import '../test_helpers/fake_work_log_repository.dart';

void main() {
  testWidgets('WorkLogToolPage 在英文环境下应展示英文文案', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WorkLogToolPage(repository: FakeWorkLogRepository()),
      ),
    );

    // 页面中可能包含持续动画组件（如 CupertinoActivityIndicator），避免使用 pumpAndSettle。
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Work Log'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);

    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('work_log_ai_input_button')),
        matching: find.byType(Icon),
      ),
    );
    expect(icon.semanticLabel, 'AI Entry');
  });
}
