import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_localizations.dart';
import '../../theme/ios26_theme.dart';
import '../message_navigation.dart';
import '../message_service.dart';
import '../models/app_message.dart';

class MessageDetailPage extends StatelessWidget {
  final int messageId;

  const MessageDetailPage({super.key, required this.messageId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: IOS26Theme.backgroundColor,
      appBar: IOS26AppBar(
        title: l10n.messages_detail_title,
        showBackButton: true,
      ),
      body: SafeArea(
        child: Consumer<MessageService>(
          builder: (context, service, _) {
            final message = _findMessage(service);
            if (message == null) {
              return Center(
                child: Text(
                  l10n.messages_not_found,
                  style: IOS26Theme.bodyMedium.copyWith(
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
                        message.title.trim().isEmpty
                            ? l10n.messages_default_title
                            : message.title,
                        style: IOS26Theme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _formatTime(message.createdAt),
                        style: IOS26Theme.bodySmall.copyWith(
                          color: IOS26Theme.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        message.body,
                        style: IOS26Theme.bodyLarge.copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (MessageNavigation.canOpen(message))
                  IOS26Button(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    variant: IOS26ButtonVariant.primary,
                    borderRadius: BorderRadius.circular(14),
                    onPressed: () => MessageNavigation.open(context, message),
                    child: IOS26ButtonLabel(
                      l10n.messages_go_to_tool,
                      style: IOS26Theme.labelLarge,
                    ),
                  )
                else
                  Text(
                    l10n.messages_no_route,
                    style: IOS26Theme.bodySmall.copyWith(
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
