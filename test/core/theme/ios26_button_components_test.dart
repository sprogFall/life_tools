import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';

void main() {
  group('IOS26Button 统一按钮组件', () {
    testWidgets('filled 语义按钮应自动应用对应背景色', (tester) async {
      IOS26Theme.setBrightness(Brightness.dark);
      final primary = IOS26Theme.buttonColors(IOS26ButtonVariant.primary);

      await tester.pumpWidget(
        CupertinoApp(
          home: IOS26Button(
            variant: IOS26ButtonVariant.primary,
            onPressed: () {},
            child: const Text('保存'),
          ),
        ),
      );

      final button = tester.widget<CupertinoButton>(
        find.byType(CupertinoButton),
      );
      expect(button.color, equals(primary.background));
    });

    testWidgets('plain 样式应保持透明背景', (tester) async {
      IOS26Theme.setBrightness(Brightness.dark);

      await tester.pumpWidget(
        CupertinoApp(
          home: IOS26Button.plain(
            variant: IOS26ButtonVariant.ghost,
            onPressed: () {},
            child: const Text('取消'),
          ),
        ),
      );

      final button = tester.widget<CupertinoButton>(
        find.byType(CupertinoButton),
      );
      expect(button.color, equals(Colors.transparent));
    });

    testWidgets('backgroundColor 显式覆盖应优先于语义色', (tester) async {
      IOS26Theme.setBrightness(Brightness.light);

      await tester.pumpWidget(
        CupertinoApp(
          home: IOS26Button(
            variant: IOS26ButtonVariant.primary,
            backgroundColor: CupertinoColors.systemPink,
            onPressed: () {},
            child: const Text('覆盖'),
          ),
        ),
      );

      final button = tester.widget<CupertinoButton>(
        find.byType(CupertinoButton),
      );
      expect(button.color, equals(CupertinoColors.systemPink));
    });
  });

  group('IOS26IconButton 统一图标按钮组件', () {
    testWidgets('plain 图标按钮应注入 tone 对应前景色', (tester) async {
      IOS26Theme.setBrightness(Brightness.light);
      final expected = IOS26Theme.iconColor(IOS26IconTone.warning);

      await tester.pumpWidget(
        CupertinoApp(
          home: IOS26IconButton(
            icon: CupertinoIcons.bell,
            tone: IOS26IconTone.warning,
            onPressed: () {},
          ),
        ),
      );

      final iconThemes = tester.widgetList<IconTheme>(
        find.descendant(
          of: find.byType(IOS26IconButton),
          matching: find.byType(IconTheme),
        ),
      );
      expect(iconThemes.any((theme) => theme.data.color == expected), isTrue);
    });

    testWidgets('chip 图标按钮应应用 chip 背景与边框', (tester) async {
      IOS26Theme.setBrightness(Brightness.dark);
      final chip = IOS26Theme.iconChipColors(IOS26IconTone.accent);

      await tester.pumpWidget(
        CupertinoApp(
          home: IOS26IconButton(
            icon: CupertinoIcons.add,
            tone: IOS26IconTone.accent,
            style: IOS26IconButtonStyle.chip,
            onPressed: () {},
          ),
        ),
      );

      final decoratedBoxes = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(IOS26IconButton),
              matching: find.byType(DecoratedBox),
            ),
          )
          .toList();

      final matched = decoratedBoxes.any((box) {
        final decoration = box.decoration;
        if (decoration is! BoxDecoration) return false;
        final border = decoration.border;
        if (border is! Border) return false;
        return decoration.color == chip.background &&
            border.top.color == chip.border;
      });

      expect(matched, isTrue);
    });
  });
}
