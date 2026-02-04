import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';

void main() {
  testWidgets('GlassContainer 路由切换期间应禁用模糊以减少掉帧', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );

    await tester.pump();

    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const _NextPage()),
    );
    await tester.pump(); // 启动 push 动画

    final glassFinder = find.byKey(
      const ValueKey('glass_container'),
      skipOffstage: false,
    );
    expect(
      find.byKey(const ValueKey('next_page'), skipOffstage: false),
      findsOneWidget,
    );
    expect(glassFinder, findsOneWidget);
    expect(
      find.descendant(
        of: glassFinder,
        matching: find.byType(BackdropFilter),
        skipOffstage: false,
      ),
      findsNothing,
    );

    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: glassFinder,
        matching: find.byType(BackdropFilter),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });
}

class _NextPage extends StatelessWidget {
  const _NextPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackdropGroup(
        child: Center(
          key: const ValueKey('next_page'),
          child: GlassContainer(
            key: const ValueKey('glass_container'),
            child: const SizedBox(width: 10, height: 10),
          ),
        ),
      ),
    );
  }
}
