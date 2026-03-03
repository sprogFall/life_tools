import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XiaoMiToolPage 布局守卫', () {
    final source = File(
      'lib/tools/xiao_mi/pages/xiao_mi_tool_page.dart',
    ).readAsStringSync();

    test('输入区不应叠加 viewInsets 底部 padding（避免键盘顶起空白）', () {
      final inputBarStart = source.indexOf('Widget _buildInputBar');
      final inputBarEnd = source.indexOf('class _WelcomePanel');
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

    test('当前会话无消息时应禁用新建聊天入口', () {
      expect(
        RegExp(
          r'!\s*service\.sending\s*&&\s*service\.messages\.isNotEmpty',
        ).hasMatch(source),
        isTrue,
      );
      expect(
        RegExp(
          r'onDone:\s*canCreateConversation\s*\?\s*\(\)\s*=>\s*Navigator\.pop\(context,\s*newChatSentinel\)\s*:\s*null',
        ).hasMatch(source),
        isTrue,
      );
    });

    test('输入区应采用顶部融合样式而非独立卡片', () {
      final inputBarStart = source.indexOf('Widget _buildInputBar');
      final inputBarEnd = source.indexOf('class _WelcomePanel');
      final inputBarSource = source.substring(inputBarStart, inputBarEnd);
      expect(inputBarSource, contains('border: Border('));
      expect(inputBarSource, contains('top: BorderSide('));
      expect(
        inputBarSource,
        isNot(
          contains('color: IOS26Theme.surfaceColor.withValues(alpha: 0.92)'),
        ),
      );
    });

    test('会话历史面板应预留顶部安全区并使用更舒展列表', () {
      final sheetStart = source.indexOf('class _XiaoMiConversationSheet');
      final sheetEnd = source.indexOf('class _ConversationRow');
      final sheetSource = source.substring(sheetStart, sheetEnd);
      expect(sheetSource, contains('top: true'));
      expect(sheetSource, contains('ListView.builder('));
      expect(sheetSource, isNot(contains('ListView.separated(')));
    });

    test('助手消息应使用气泡容器且不再渲染预选 badge', () {
      expect(source, contains('final assistantBg ='));
      expect(source, isNot(contains('isUser ? userBg : Colors.transparent')));
      expect(source, isNot(contains('class _PresetBadge')));
    });

    test('消息气泡应提供复制按钮并支持长按进入多选删除', () {
      expect(source, contains('Clipboard.setData'));
      expect(source, contains('onLongPress'));
      expect(source, contains('_selectionMode'));
      expect(source, contains('_selectedMessageIds'));
      expect(source, contains('deleteMessages('));
    });
  });
}
