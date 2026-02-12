import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';
import 'package:life_tools/core/ui/app_scaffold.dart';

void main() {
  testWidgets('GlassContainer 在 BackdropGroup 下应复用 backdropKey', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackdropGroup(
            child: GlassContainer(child: const SizedBox(width: 10, height: 10)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final filterFinder = find.descendant(
      of: find.byType(GlassContainer),
      matching: find.byType(BackdropFilter),
    );
    expect(filterFinder, findsOneWidget);

    final renderObject = tester.renderObject(filterFinder);
    expect(renderObject, isA<RenderBackdropFilter>());
    final renderBackdropFilter = renderObject as RenderBackdropFilter;
    expect(renderBackdropFilter.backdropKey, isNotNull);
  });

  testWidgets('AppScaffold 默认应提供 BackdropGroup', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AppScaffold(body: SizedBox.shrink())),
    );
    expect(find.byType(BackdropGroup), findsOneWidget);
  });
}
