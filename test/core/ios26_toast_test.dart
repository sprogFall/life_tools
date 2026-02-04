import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:life_tools/core/widgets/ios26_toast.dart';

import '../test_helpers/test_app_wrapper.dart';

void main() {
  testWidgets('IOS26ToastOverlay：显示后自动消失', (tester) async {
    final toastService = ToastService();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => toastService,
        child: const TestAppWrapper(
          child: Stack(children: [SizedBox(), IOS26ToastOverlay()]),
        ),
      ),
    );

    expect(find.text('同步成功'), findsNothing);

    toastService.showSuccess(
      '同步成功',
      duration: const Duration(milliseconds: 200),
    );
    await tester.pump();

    expect(find.text('同步成功'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('同步成功'), findsNothing);
  });

  testWidgets('IOS26ToastOverlay：新的提示会替换旧提示', (tester) async {
    final toastService = ToastService();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => toastService,
        child: const TestAppWrapper(
          child: Stack(children: [SizedBox(), IOS26ToastOverlay()]),
        ),
      ),
    );

    toastService.showSuccess('A', duration: const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('A'), findsOneWidget);

    toastService.showError('B', duration: const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.text('A'), findsNothing);
    expect(find.text('B'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();
  });
}
