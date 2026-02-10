import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';

void main() {
  group('IOS26Theme 暗黑模式', () {
    test('切换亮暗主题时应提供可读的前景与背景色', () {
      IOS26Theme.setBrightness(Brightness.light);
      final lightBackground = IOS26Theme.backgroundColor;
      final lightText = IOS26Theme.textPrimary;

      IOS26Theme.setBrightness(Brightness.dark);
      final darkBackground = IOS26Theme.backgroundColor;
      final darkText = IOS26Theme.textPrimary;

      expect(lightBackground, isNot(darkBackground));
      expect(lightText, isNot(darkText));
      expect(darkText, isNot(darkBackground));
      expect(IOS26Theme.onPrimaryColor, isNot(IOS26Theme.primaryColor));
    });

    test('暗黑模式背景应为纯黑色，降低屏幕发光', () {
      final darkTheme = IOS26Theme.darkTheme;
      expect(darkTheme.scaffoldBackgroundColor, const Color(0xFF000000));
      expect(darkTheme.canvasColor, const Color(0xFF000000));
    });
  });
}
