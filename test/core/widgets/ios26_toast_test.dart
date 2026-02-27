import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';
import 'package:life_tools/core/widgets/ios26_toast.dart';
import 'package:provider/provider.dart';

void main() {
  test('ToastService.show 会去掉尾部仅由下划线组成的行', () {
    final service = ToastService();
    addTearDown(service.dispose);

    service.show('自动同步成功\n__');
    expect(service.toast?.message, '自动同步成功');
  });

  test('ToastService.show 若清洗后为空则不应展示', () {
    final service = ToastService();
    addTearDown(service.dispose);

    service.show('__');
    expect(service.toast, isNull);
  });

  testWidgets('IOS26ToastOverlay 底部 padding 应包含 systemGestureInsets', (
    tester,
  ) async {
    late ToastService service;

    await tester.pumpWidget(
      ChangeNotifierProvider<ToastService>(
        create: (_) {
          service = ToastService();
          return service;
        },
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              padding: EdgeInsets.zero,
              systemGestureInsets: EdgeInsets.only(bottom: 34),
            ),
            child: const Stack(
              children: [SizedBox.expand(), IOS26ToastOverlay()],
            ),
          ),
        ),
      ),
    );

    service.show('测试文案');
    await tester.pump();

    final overlayRow = find.byKey(IOS26ToastOverlay.overlayKey);
    expect(overlayRow, findsOneWidget);

    final paddingFinder = find.ancestor(
      of: overlayRow,
      matching: find.byWidgetPredicate((widget) {
        if (widget is! Padding) return false;
        final edgeInsets = widget.padding;
        if (edgeInsets is! EdgeInsets) return false;
        return edgeInsets.left == IOS26Theme.spacingXl &&
            edgeInsets.right == IOS26Theme.spacingXl &&
            edgeInsets.top == 0;
      }),
    );
    expect(paddingFinder, findsOneWidget);

    final padding = tester.widget<Padding>(paddingFinder);
    final edgeInsets = padding.padding as EdgeInsets;
    expect(edgeInsets.bottom, IOS26Theme.spacingXl + 34);
  });
}
