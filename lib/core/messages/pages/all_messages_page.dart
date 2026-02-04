import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/ios26_theme.dart';
import '../message_navigation.dart';
import '../message_service.dart';
import '../models/app_message.dart';
import 'message_detail_page.dart';

class AllMessagesPage extends StatelessWidget {
  const AllMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: const IOS26AppBar(title: '全部消息', showBackButton: true),
      body: SafeArea(
        child: BackdropGroup(
          child: Consumer<MessageService>(
            builder: (context, service, _) {
              final messages = service.messages;
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    '当前暂时没有消息',
                    style: IOS26Theme.bodyMedium.copyWith(
                      color: IOS26Theme.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: messages.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
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
    final messageId = message.id;
    final service = context.read<MessageService>();

    final content = GlassContainer(
      padding: const EdgeInsets.all(14),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: messageId == null
            ? null
            : () async {
                if (!message.isRead) {
                  await service.markMessageRead(messageId);
                }
                if (!context.mounted) return;
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
                    message.title.trim().isEmpty ? '消息' : message.title,
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
            const SizedBox(height: 10),
            Row(
              children: [
                _ReadTag(isRead: message.isRead),
                const Spacer(),
                if (MessageNavigation.canOpen(message))
                  Text('前往工具', style: IOS26Theme.labelLarge),
              ],
            ),
          ],
        ),
      ),
    );

    if (messageId == null || message.isRead) {
      return content;
    }

    return Dismissible(
      key: ValueKey('all_messages_item_$messageId'),
      direction: DismissDirection.startToEnd,
      background: _SwipeReadBackground(),
      confirmDismiss: (_) async {
        await service.markMessageRead(messageId);
        return false;
      },
      child: content,
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
    final text = isRead ? '已读' : '未读';
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

class _SwipeReadBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 18),
      decoration: BoxDecoration(
        color: IOS26Theme.toolGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '标记已读',
        style: IOS26Theme.bodySmall.copyWith(
          fontWeight: FontWeight.w600,
          color: IOS26Theme.toolGreen,
        ),
      ),
    );
  }
}
