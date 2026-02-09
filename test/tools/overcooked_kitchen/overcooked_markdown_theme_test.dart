import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';
import 'package:life_tools/tools/overcooked_kitchen/widgets/overcooked_markdown.dart';

void main() {
  test('暗黑模式下 Markdown 正文和背景不应同色', () {
    IOS26Theme.setBrightness(Brightness.dark);

    final styleSheet = overcookedMarkdownStyleSheet();
    final paragraphColor = styleSheet.p?.color;
    final codeDecoration = styleSheet.codeblockDecoration as BoxDecoration?;
    final codeBackgroundColor = codeDecoration?.color;

    expect(paragraphColor, equals(IOS26Theme.textPrimary));
    expect(paragraphColor, isNot(IOS26Theme.backgroundColor));
    expect(codeBackgroundColor, isNotNull);
    expect(codeBackgroundColor, isNot(IOS26Theme.backgroundColor));
  });
}
