import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';
import 'package:life_tools/core/widgets/ios26_markdown.dart';

void main() {
  test('暗黑模式下 IOS26 Markdown 正文与背景不应同色', () {
    IOS26Theme.setBrightness(Brightness.dark);

    final styleSheet = ios26MarkdownStyleSheet();
    final paragraphColor = styleSheet.p?.color;
    final codeDecoration = styleSheet.codeblockDecoration as BoxDecoration?;
    final codeBackgroundColor = codeDecoration?.color;

    expect(paragraphColor, equals(IOS26Theme.textPrimary));
    expect(paragraphColor, isNot(IOS26Theme.backgroundColor));
    expect(codeBackgroundColor, isNotNull);
    expect(codeBackgroundColor, isNot(IOS26Theme.backgroundColor));
  });
}
