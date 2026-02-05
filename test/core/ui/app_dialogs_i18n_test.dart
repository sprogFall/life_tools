import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ui/app_dialogs.dart';

import '../../test_helpers/test_app_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppDialogs 默认按钮文案应随 locale 变化（英文）', (tester) async {
    const hostKey = ValueKey('host');

    await tester.pumpWidget(
      const TestAppWrapper(
        locale: Locale('en', 'US'),
        child: SizedBox(key: hostKey),
      ),
    );

    final ctx = tester.element(find.byKey(hostKey));

    // showInfo: 默认按钮应为 Confirm
    AppDialogs.showInfo(ctx, title: 't', content: 'c');
    await tester.pumpAndSettle();
    expect(find.text('Confirm'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    // showConfirm: 默认按钮应为 Cancel / Confirm
    final confirmFuture = AppDialogs.showConfirm(ctx, title: 't', content: 'c');
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Confirm'), findsOneWidget);
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(await confirmFuture, isTrue);

    // showLoading: 默认标题应为 Loading...
    AppDialogs.showLoading(ctx);
    await tester.pump();
    expect(find.text('Loading...'), findsOneWidget);
    Navigator.of(ctx).pop();
    await tester.pumpAndSettle();
  });
}
