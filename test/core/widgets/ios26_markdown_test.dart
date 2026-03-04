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

  test('Markdown 表格默认应启用移动端友好列宽策略', () {
    final styleSheet = ios26MarkdownStyleSheet();
    final columnWidth = styleSheet.tableColumnWidth;

    expect(columnWidth, isA<MaxColumnWidth>());
    final maxWidth = columnWidth! as MaxColumnWidth;
    expect(maxWidth.a, isA<FixedColumnWidth>());
    expect((maxWidth.a as FixedColumnWidth).value, closeTo(136, 0.01));

    expect(maxWidth.b, isA<MinColumnWidth>());
    final minWidth = maxWidth.b as MinColumnWidth;
    expect(minWidth.a, isA<IntrinsicColumnWidth>());
    expect(minWidth.b, isA<FixedColumnWidth>());
    expect((minWidth.b as FixedColumnWidth).value, closeTo(240, 0.01));
  });
}
