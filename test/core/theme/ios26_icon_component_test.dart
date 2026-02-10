import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';

void main() {
  testWidgets('IOS26Icon 应根据 tone 自动注入颜色', (tester) async {
    IOS26Theme.setBrightness(Brightness.dark);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IOS26Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            tone: IOS26IconTone.warning,
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, IOS26Theme.iconColor(IOS26IconTone.warning));
  });

  testWidgets('IOS26Icon 的显式 color 应优先于 tone', (tester) async {
    const customColor = Color(0xFF123456);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: IOS26Icon(
            CupertinoIcons.heart_fill,
            tone: IOS26IconTone.danger,
            color: customColor,
          ),
        ),
      ),
    );

    final icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.color, customColor);
  });
}
