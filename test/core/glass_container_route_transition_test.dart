import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';

void main() {
  test('GlassContainer 仅在路由 reverse 状态禁用模糊', () {
    expect(
      GlassContainer.shouldDisableBlurForRouteStatus(AnimationStatus.dismissed),
      isFalse,
    );
    expect(
      GlassContainer.shouldDisableBlurForRouteStatus(AnimationStatus.forward),
      isFalse,
    );
    expect(
      GlassContainer.shouldDisableBlurForRouteStatus(AnimationStatus.completed),
      isFalse,
    );
    expect(
      GlassContainer.shouldDisableBlurForRouteStatus(AnimationStatus.reverse),
      isTrue,
    );
  });

  testWidgets('GlassContainer pop 期间应临时关闭模糊以减轻动画压力', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const SizedBox.shrink()),
    );

    await tester.pump();
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => const _NextPage()),
    );
    await tester.pumpAndSettle();

    navigatorKey.currentState!.pop();
    await tester.pump(); // 启动 pop 动画

    final glassFinder = find.byKey(
      const ValueKey('glass_container'),
      skipOffstage: false,
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
    expect(glassFinder, findsNothing);
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
