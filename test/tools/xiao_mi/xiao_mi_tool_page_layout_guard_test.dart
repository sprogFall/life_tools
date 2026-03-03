import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XiaoMiToolPage 布局守卫', () {
    final source = File(
      'lib/tools/xiao_mi/pages/xiao_mi_tool_page.dart',
    ).readAsStringSync();

    test('输入区不应叠加 viewInsets 底部 padding（避免键盘顶起空白）', () {
      final inputBarStart = source.indexOf('Widget _buildInputBar');
      final inputBarEnd = source.indexOf('class _GlowCircle');
      final inputBarSource = source.substring(inputBarStart, inputBarEnd);
      expect(
        inputBarSource,
        isNot(contains('MediaQuery.viewInsetsOf(context).bottom')),
      );
    });

    test('空会话欢迎态应使用融合式欢迎区而非旧版 _EmptyState 卡片', () {
      expect(source, isNot(contains('return _EmptyState(')));
      expect(source, contains('class _WelcomePanel'));
    });
  });
}
