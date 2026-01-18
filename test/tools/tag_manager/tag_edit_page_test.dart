import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/theme/ios26_theme.dart';
import 'package:life_tools/tools/tag_manager/pages/tag_edit_page.dart';

void main() {
  group('TagEditPage', () {
    testWidgets('标签名示例文字应为灰色', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: TagEditPage()));

      final field = tester.widget<TextField>(find.byType(TextField));
      final styleColor = field.decoration?.hintStyle?.color;

      expect(field.decoration?.hintText, '例如：紧急 / 例行 / 复盘');
      expect(styleColor, IOS26Theme.textSecondary);
      expect(styleColor, isNot(equals(Colors.black)));
    });
  });
}
