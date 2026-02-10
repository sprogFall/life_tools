import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';

void main() {
  group('IOS26Theme 按钮与图标语义样式', () {
    test('主按钮在明暗模式都应保持前景对比', () {
      IOS26Theme.setBrightness(Brightness.light);
      final light = IOS26Theme.buttonColors(IOS26ButtonVariant.primary);

      IOS26Theme.setBrightness(Brightness.dark);
      final dark = IOS26Theme.buttonColors(IOS26ButtonVariant.primary);

      expect(light.background, isNot(light.foreground));
      expect(dark.background, isNot(dark.foreground));
      expect(light.background, isNot(dark.background));
    });

    test('次级按钮在暗黑模式下不应贴近纯黑背景', () {
      IOS26Theme.setBrightness(Brightness.dark);
      final secondary = IOS26Theme.buttonColors(IOS26ButtonVariant.secondary);

      expect(secondary.background, isNot(const Color(0xFF000000)));
      expect(secondary.foreground, isNot(secondary.background));
      expect(secondary.border, isNot(Colors.transparent));
    });

    test('高强调危险按钮在明暗模式都应保持可读性', () {
      IOS26Theme.setBrightness(Brightness.light);
      final light = IOS26Theme.buttonColors(
        IOS26ButtonVariant.destructivePrimary,
      );

      IOS26Theme.setBrightness(Brightness.dark);
      final dark = IOS26Theme.buttonColors(
        IOS26ButtonVariant.destructivePrimary,
      );

      expect(light.foreground, equals(IOS26Theme.onPrimaryColor));
      expect(dark.foreground, equals(IOS26Theme.onPrimaryColor));
      expect(light.background, isNot(light.foreground));
      expect(dark.background, isNot(dark.foreground));
    });

    test('高亮按钮在明暗模式都应切换独立紫色层级', () {
      IOS26Theme.setBrightness(Brightness.light);
      final light = IOS26Theme.buttonColors(IOS26ButtonVariant.highlight);

      IOS26Theme.setBrightness(Brightness.dark);
      final dark = IOS26Theme.buttonColors(IOS26ButtonVariant.highlight);

      expect(light.background, isNot(light.foreground));
      expect(dark.background, isNot(dark.foreground));
      expect(light.background, isNot(dark.background));
    });

    test('警告按钮在明暗模式都应保持橙色可读性', () {
      IOS26Theme.setBrightness(Brightness.light);
      final light = IOS26Theme.buttonColors(IOS26ButtonVariant.warning);

      IOS26Theme.setBrightness(Brightness.dark);
      final dark = IOS26Theme.buttonColors(IOS26ButtonVariant.warning);

      expect(light.background, isNot(light.foreground));
      expect(dark.background, isNot(dark.foreground));
      expect(light.foreground, isNot(Colors.transparent));
      expect(dark.foreground, isNot(Colors.transparent));
    });

    test('成功主按钮在明暗模式都应保持白色前景', () {
      IOS26Theme.setBrightness(Brightness.light);
      final light = IOS26Theme.buttonColors(IOS26ButtonVariant.successPrimary);

      IOS26Theme.setBrightness(Brightness.dark);
      final dark = IOS26Theme.buttonColors(IOS26ButtonVariant.successPrimary);

      expect(light.foreground, equals(IOS26Theme.onPrimaryColor));
      expect(dark.foreground, equals(IOS26Theme.onPrimaryColor));
      expect(light.background, isNot(light.foreground));
      expect(dark.background, isNot(dark.foreground));
    });

    test('图标胶囊在明暗模式都应切换独立配色', () {
      IOS26Theme.setBrightness(Brightness.light);
      final light = IOS26Theme.iconChipColors(IOS26IconTone.accent);

      IOS26Theme.setBrightness(Brightness.dark);
      final dark = IOS26Theme.iconChipColors(IOS26IconTone.accent);

      expect(light.background, isNot(light.foreground));
      expect(dark.background, isNot(dark.foreground));
      expect(light.background, isNot(dark.background));
    });
  });
}
