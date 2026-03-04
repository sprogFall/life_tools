import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XiaoMiToolPage 布局守卫', () {
    final source = File(
      'lib/tools/xiao_mi/pages/xiao_mi_tool_page.dart',
    ).readAsStringSync();

    test('输入区不应叠加 viewInsets 底部 padding（避免键盘顶起空白）', () {
      // 输入区域已提取到 ChatInputBar 组件
      final inputBarSource = File(
        'lib/tools/xiao_mi/widgets/chat_input_bar.dart',
      ).readAsStringSync();
      expect(
        inputBarSource,
        isNot(contains('MediaQuery.viewInsetsOf(context).bottom')),
      );
    });

    test('空会话欢迎态应使用 ChatEmptyState 组件', () {
      expect(source, contains('ChatEmptyState'));
      expect(
        File('lib/tools/xiao_mi/widgets/chat_empty_state.dart').existsSync(),
        isTrue,
      );
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
      final inputBarSource = File(
        'lib/tools/xiao_mi/widgets/chat_input_bar.dart',
      ).readAsStringSync();
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

    test('助手消息应使用气泡容器', () {
      final bubbleSource = File(
        'lib/tools/xiao_mi/widgets/chat_message_bubble.dart',
      ).readAsStringSync();
      expect(bubbleSource, contains('GlassContainer'));
    });

    test('消息气泡应提供复制按钮并支持长按进入多选删除', () {
      expect(source, contains('Clipboard.setData'));
      expect(
        File(
          'lib/tools/xiao_mi/widgets/chat_message_bubble.dart',
        ).readAsStringSync(),
        contains('onLongPress'),
      );
      expect(source, contains('_selectionMode'));
      expect(source, contains('_selectedMessageIds'));
      expect(source, contains('deleteMessages('));
    });

    test('应使用 ChatTypingIndicator 显示AI输入状态', () {
      expect(source, contains('ChatTypingIndicator'));
      expect(
        File(
          'lib/tools/xiao_mi/widgets/chat_typing_indicator.dart',
        ).existsSync(),
        isTrue,
      );
    });

    test('应使用 ChatMessageList 组件管理消息列表', () {
      expect(source, contains('ChatMessageList'));
      expect(
        File(
          'lib/tools/xiao_mi/widgets/chat_message_list.dart',
        ).existsSync(),
        isTrue,
      );
    });

    test('应使用 ChatInputBar 组件作为底部输入区', () {
      expect(source, contains('ChatInputBar'));
      expect(
        File('lib/tools/xiao_mi/widgets/chat_input_bar.dart').existsSync(),
        isTrue,
      );
    });
  });
}
