import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/backup/pages/backup_restore_page.dart';

import '../test_helpers/test_app_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('BackupRestorePage 在英文环境下应展示英文文案', (tester) async {
    await tester.pumpWidget(
      const TestAppWrapper(
        locale: Locale('en', 'US'),
        child: BackupRestorePage(),
      ),
    );

    await tester.pump();

    expect(find.text('Backup & Restore'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    expect(find.textContaining('Export & Share'), findsOneWidget);
  });
}

