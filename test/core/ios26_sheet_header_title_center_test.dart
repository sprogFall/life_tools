import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/widgets/ios26_sheet_header.dart';

void main() {
  group('IOS26SheetHeader 标题居中', () {
    void expectCentered(WidgetTester tester, String title) {
      final headerRect = tester.getRect(find.byType(IOS26SheetHeader));
      final titleRect = tester.getRect(find.text(title));
      final expectedCenterX = headerRect.left + headerRect.width / 2;
      expect(
        titleRect.center.dx,
        moreOrLessEquals(expectedCenterX, epsilon: 0.5),
      );
    }

    testWidgets('左右按钮宽度不对称时标题仍应居中', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: SizedBox(
              width: 390,
              child: IOS26SheetHeader(
                title: '选择标签',
                cancelText: '取消',
                doneText: '完成并保存',
                onCancel: () {},
                onDone: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expectCentered(tester, '选择标签');
    });
  });
}

