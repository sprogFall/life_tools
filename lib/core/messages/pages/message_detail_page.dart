import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/ios26_theme.dart';
import '../message_navigation.dart';
import '../message_service.dart';
import '../models/app_message.dart';

class MessageDetailPage extends StatelessWidget {
  final int messageId;

  const MessageDetailPage({super.key, required this.messageId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: const IOS26AppBar(title: '消息详情', showBackButton: true),
      body: SafeArea(
        child: Consumer<MessageService>(
          builder: (context, service, _) {
            final message = _findMessage(service);
            if (message == null) {
              return Center(
                child: Text(
                  '消息不存在或已被删除',
                  style: TextStyle(
                    fontSize: 14,
                    color: IOS26Theme.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.title.trim().isEmpty ? '消息' : message.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: IOS26Theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatTime(message.createdAt),
                        style: const TextStyle(
                          fontSize: 13,
                          color: IOS26Theme.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        message.body,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          color: IOS26Theme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (MessageNavigation.canOpen(message))
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    color: IOS26Theme.primaryColor,
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () => MessageNavigation.open(context, message),
                    child: const Text(
                      '前往工具',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Text(
                    '该消息未提供可跳转的工具路由',
                    style: TextStyle(
                      fontSize: 13,
                      color: IOS26Theme.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  AppMessage? _findMessage(MessageService service) {
    for (final m in service.messages) {
      if (m.id == messageId) return m;
    }
    return null;
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
