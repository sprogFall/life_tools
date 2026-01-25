import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';

void main() {
  group('IOS26QuickAddChip', () {
    testWidgets('默认只显示加号，提交后收起', (tester) async {
      final textController = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(() {
        textController.dispose();
        focusNode.dispose();
      });

      const fieldKey = ValueKey('field');
      const buttonKey = ValueKey('button');

      String? committed;

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: IOS26QuickAddChip(
                fieldKey: fieldKey,
                buttonKey: buttonKey,
                controller: textController,
                focusNode: focusNode,
                placeholder: '输入标签名',
                loading: false,
                onAdd: (name) {
                  committed = name;
                  return true;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(fieldKey), findsNothing);
      expect(find.byKey(buttonKey), findsOneWidget);

      await tester.tap(find.byKey(buttonKey));
      await tester.pump();
      expect(find.byKey(fieldKey), findsOneWidget);

      await tester.enterText(find.byKey(fieldKey), '咸');
      await tester.pump();

      await tester.tap(find.byKey(buttonKey));
      await tester.pumpAndSettle();

      expect(committed, '咸');
      expect(find.byKey(fieldKey), findsNothing);
    });

    testWidgets('输入越长，输入框宽度越大', (tester) async {
      final textController = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(() {
        textController.dispose();
        focusNode.dispose();
      });

      const fieldKey = ValueKey('field');
      const buttonKey = ValueKey('button');

      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: IOS26QuickAddChip(
                fieldKey: fieldKey,
                buttonKey: buttonKey,
                controller: textController,
                focusNode: focusNode,
                placeholder: '输入标签名',
                loading: false,
                onAdd: (_) => true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(buttonKey));
      await tester.pump();

      final w1 = tester.getSize(find.byKey(fieldKey)).width;

      await tester.enterText(find.byKey(fieldKey), '这是一个比较长的标签名');
      await tester.pump();

      final w2 = tester.getSize(find.byKey(fieldKey)).width;
      expect(w2, greaterThan(w1));
    });
  });
}

