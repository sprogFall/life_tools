import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void expectBottomRightFloatingIconButton(
  WidgetTester tester, {
  required Key buttonKey,
  required IconData icon,
  String? shouldNotFindText,
}) {
  final buttonFinder = find.byKey(buttonKey);
  expect(buttonFinder, findsOneWidget);

  if (shouldNotFindText != null) {
    expect(
      find.descendant(of: buttonFinder, matching: find.text(shouldNotFindText)),
      findsNothing,
    );
  }

  expect(
    find.descendant(of: buttonFinder, matching: find.byIcon(icon)),
    findsOneWidget,
  );

  final positionedFinder = find.ancestor(
    of: buttonFinder,
    matching: find.byType(Positioned),
  );
  expect(positionedFinder, findsOneWidget);

  final positioned = tester.widget<Positioned>(positionedFinder);
  expect(positioned.right, isNotNull);
  expect(positioned.left, isNull);
}
