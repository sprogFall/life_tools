import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';

void main() {
  group('IOS26AppBar 标题居中', () {
    Future<void> pumpWithAppBar(
      WidgetTester tester, {
      required IOS26AppBar appBar,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(appBar: appBar, body: const SizedBox.shrink()),
        ),
      );
      await tester.pump();
    }

    void expectTitleCentered(WidgetTester tester, String title) {
      final barRect = tester.getRect(find.byType(IOS26AppBar));
      final titleRect = tester.getRect(find.text(title));
      final expectedCenterX = barRect.left + barRect.width / 2;
      expect(
        titleRect.center.dx,
        moreOrLessEquals(expectedCenterX, epsilon: 0.5),
      );
    }

    testWidgets('无 actions 时标题仍应居中', (tester) async {
      await pumpWithAppBar(
        tester,
        appBar: const IOS26AppBar(title: '全部消息', showBackButton: true),
      );

      expectTitleCentered(tester, '全部消息');
    });

    testWidgets('左右宽度不对称时标题仍应居中', (tester) async {
      await pumpWithAppBar(
        tester,
        appBar: IOS26AppBar(
          title: '工作记录',
          leading: SizedBox(
            width: 140,
            child: CupertinoButton(
              padding: const EdgeInsets.all(8),
              onPressed: () {},
              child: const Text('首页'),
            ),
          ),
          actions: const [
            SizedBox(width: 10),
            SizedBox(width: 44, height: 44),
            SizedBox(width: 44, height: 44),
          ],
        ),
      );

      expectTitleCentered(tester, '工作记录');
    });
  });
}
