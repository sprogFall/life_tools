import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/ios26_theme.dart';
import '../message_navigation.dart';
import '../message_service.dart';
import '../models/app_message.dart';
import 'message_detail_page.dart';

class AllMessagesPage extends StatelessWidget {
  const AllMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(title: l10n.messages_all_title, showBackButton: true),
      body: SafeArea(
        child: BackdropGroup(
          child: Consumer<MessageService>(
            builder: (context, service, _) {
              final messages = service.messages;
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    l10n.messages_empty,
                    style: IOS26Theme.bodyMedium.copyWith(
                      color: IOS26Theme.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: messages.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return _MessageListItem(message: message);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MessageListItem extends StatelessWidget {
  final AppMessage message;

  const _MessageListItem({required this.message});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messageId = message.id;
    final service = context.read<MessageService>();

    final hasSlidable = messageId != null;
    final content = GlassContainer(
      borderRadius: hasSlidable ? 0 : 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CupertinoButton(
            key: messageId == null
                ? null
                : ValueKey('all_messages_content_$messageId'),
            padding: EdgeInsets.zero,
            onPressed: messageId == null
                ? null
                : () {
                    if (!message.isRead) {
                      unawaited(service.markMessageRead(messageId));
                    }
                    Navigator.of(context).push(
                      CupertinoPageRoute<void>(
                        builder: (_) => MessageDetailPage(messageId: messageId),
                      ),
                    );
                  },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.title.trim().isEmpty
                            ? l10n.messages_default_title
                            : message.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IOS26Theme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _formatTime(message.createdAt),
                      style: IOS26Theme.bodySmall.copyWith(
                        color: IOS26Theme.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message.body,
                  style: IOS26Theme.bodyMedium.copyWith(
                    height: 1.25,
                    color: message.isRead
                        ? IOS26Theme.textSecondary.withValues(alpha: 0.7)
                        : IOS26Theme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ReadTag(isRead: message.isRead),
              const Spacer(),
              if (messageId != null && MessageNavigation.canOpen(message))
                CupertinoButton(
                  key: ValueKey('all_messages_open_tool_$messageId'),
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () {
                    if (!message.isRead) {
                      unawaited(service.markMessageRead(messageId));
                    }
                    MessageNavigation.open(context, message);
                  },
                  child: Text(
                    l10n.messages_go_to_tool,
                    style: IOS26Theme.labelLarge,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (messageId == null) {
      return content;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Slidable(
        key: ValueKey('all_messages_item_$messageId'),
        startActionPane: message.isRead
            ? null
            : ActionPane(
                motion: const StretchMotion(),
                extentRatio: 0.26,
                children: [
                  SlidableAction(
                    onPressed: (_) {
                      unawaited(service.markMessageRead(messageId));
                    },
                    backgroundColor: IOS26Theme.toolGreen,
                    foregroundColor: IOS26Theme.onPrimaryColor,
                    icon: CupertinoIcons.check_mark_circled_solid,
                    label: l10n.messages_read_label,
                  ),
                ],
              ),
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          extentRatio: 0.26,
          children: [
            SlidableAction(
              onPressed: (_) {
                unawaited(service.deleteMessage(messageId));
              },
              backgroundColor: IOS26Theme.toolRed,
              foregroundColor: IOS26Theme.onPrimaryColor,
              icon: CupertinoIcons.delete_solid,
              label: l10n.common_delete,
            ),
          ],
        ),
        child: content,
      ),
    );
  }

  static String _formatTime(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

class _ReadTag extends StatelessWidget {
  final bool isRead;

  const _ReadTag({required this.isRead});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = isRead ? l10n.messages_read_label : l10n.messages_unread_label;
    final color = isRead ? IOS26Theme.textTertiary : IOS26Theme.primaryColor;
    final background = isRead
        ? IOS26Theme.textTertiary.withValues(alpha: 0.15)
        : IOS26Theme.primaryColor.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: IOS26Theme.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
