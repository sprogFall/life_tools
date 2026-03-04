import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../ai/xiao_mi_prompt_resolver.dart';
import '../models/xiao_mi_message.dart';
import '../services/xiao_mi_chat_service.dart';
import 'chat_empty_state.dart';
import 'chat_message_bubble.dart';
import 'chat_typing_indicator.dart';

/// ChatGPT风格消息列表
class ChatMessageList extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onScrollToBottom;
  final void Function(XiaoMiMessage, XiaoMiChatService) onLongPressMessage;
  final void Function(XiaoMiMessage) onTapMessage;
  final Future<void> Function(String) onCopyMessage;
  final void Function(XiaoMiQuickPrompt) onTapPrompt;
  final bool selectionMode;
  final Set<int> selectedMessageIds;
  final bool showScrollToBottom;

  const ChatMessageList({
    super.key,
    required this.scrollController,
    required this.onScrollToBottom,
    required this.onLongPressMessage,
    required this.onTapMessage,
    required this.onCopyMessage,
    required this.onTapPrompt,
    required this.selectionMode,
    required this.selectedMessageIds,
    this.showScrollToBottom = false,
  });

  /// 判断是否显示头像（当消息角色变化时显示）
  bool _shouldShowAvatar(List<XiaoMiMessage> messages, int index) {
    if (index == 0) return true;
    final current = messages[index];
    final previous = messages[index - 1];
    return current.role != previous.role;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<XiaoMiChatService>(
      builder: (context, service, _) {
        final messages = service.messages;

        // 空状态
        if (messages.isEmpty) {
          return ListView(
            controller: scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              IOS26Theme.spacingXl,
              IOS26Theme.spacingMd,
              IOS26Theme.spacingXl,
              IOS26Theme.spacingXl,
            ),
            children: [
              ChatEmptyState(
                title: AppLocalizations.of(context)!.xiao_mi_empty_title,
                subtitle: AppLocalizations.of(context)!.xiao_mi_empty_subtitle,
                prompts: service.quickPrompts,
                onTapPrompt: onTapPrompt,
              ),
            ],
          );
        }

        // 自动滚动到底部（仅在未手动上滑时）
        if (!showScrollToBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onScrollToBottom();
          });
        }

        return ListView.builder(
          controller: scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            IOS26Theme.spacingMd,
            IOS26Theme.spacingMd,
            IOS26Theme.spacingMd,
            IOS26Theme.spacingMd,
          ),
          itemCount:
              messages.length +
              ((service.sending && !service.hasStreamingAssistantDraft)
                  ? 1
                  : 0),
          itemBuilder: (context, index) {
            // 打字指示器
            if (index >= messages.length) {
              return const ChatTypingIndicator();
            }

            final message = messages[index];
            final messageId = message.id;
            final showAvatar = _shouldShowAvatar(messages, index);

            return ChatMessageBubble(
              key: ValueKey('xiao_mi_message_${messageId ?? 'draft_$index'}'),
              message: message,
              selectionMode: selectionMode,
              selected:
                  messageId != null && selectedMessageIds.contains(messageId),
              showAvatar: showAvatar,
              onTap: () => onTapMessage(message),
              onLongPress: () => onLongPressMessage(message, service),
              onCopy: () => onCopyMessage(message.content),
            );
          },
        );
      },
    );
  }
}
