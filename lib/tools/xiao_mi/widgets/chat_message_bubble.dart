import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/ios26_theme.dart';
import '../../../core/widgets/ios26_markdown.dart';
import '../../../l10n/app_localizations.dart';
import '../models/xiao_mi_message.dart';
import '../services/xiao_mi_chat_service.dart';
import 'chat_thinking_panel.dart';

/// ChatGPT风格消息气泡
class ChatMessageBubble extends StatelessWidget {
  final XiaoMiMessage message;
  final bool selectionMode;
  final bool selected;
  final bool showAvatar;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onCopy;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.selectionMode,
    required this.selected,
    this.showAvatar = true,
    required this.onTap,
    required this.onLongPress,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isUser = message.role == XiaoMiMessageRole.user;

    return Padding(
      padding: EdgeInsets.only(
        bottom: showAvatar ? IOS26Theme.spacingMd : IOS26Theme.spacingXs,
      ),
      child: GestureDetector(
        onTap: selectionMode ? onTap : null,
        onLongPress: onLongPress,
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            // AI头像（只在AI消息且需要显示时）
            if (!isUser && showAvatar) ...[
              _buildAiAvatar(),
              const SizedBox(width: IOS26Theme.spacingSm),
            ],
            if (isUser) const Spacer(),
            // 气泡内容
            Flexible(
              flex: 4,
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  _buildBubbleContent(context, l10n, isUser),
                  // 复制按钮（hover效果）
                  if (!isUser && !selectionMode) ...[
                    const SizedBox(height: 2),
                    _CopyButton(onCopy: onCopy),
                  ],
                ],
              ),
            ),
            if (!isUser) const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [IOS26Theme.primaryColor, IOS26Theme.secondaryColor],
        ),
      ),
      child: const IOS26Icon(
        CupertinoIcons.bubble_left_fill,
        size: 14,
        tone: IOS26IconTone.onAccent,
      ),
    );
  }

  Widget _buildBubbleContent(
    BuildContext context,
    AppLocalizations l10n,
    bool isUser,
  ) {
    final maxWidth = MediaQuery.sizeOf(context).width * (isUser ? 0.75 : 0.85);

    // 用户消息使用绿色气泡，AI消息使用毛玻璃卡片
    if (isUser) {
      return _buildUserBubble(l10n, maxWidth);
    } else {
      return _buildAiBubble(context, l10n, maxWidth);
    }
  }

  Widget _buildUserBubble(AppLocalizations l10n, double maxWidth) {
    final presetId = (message.metadata ?? const {})['presetId'] as String?;
    final triggerHint = _resolveTriggerHint(l10n, presetId);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              IOS26Theme.toolGreen,
              IOS26Theme.toolGreen.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: IOS26Theme.toolGreen.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(
          IOS26Theme.spacingMd,
          IOS26Theme.spacingSm,
          IOS26Theme.spacingMd,
          IOS26Theme.spacingSm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectionMode && message.id != null) ...[
              IOS26Icon(
                selected
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                size: 16,
                color: IOS26Theme.onPrimaryColor.withValues(alpha: 0.9),
              ),
              const SizedBox(height: IOS26Theme.spacingXs),
            ],
            SelectableText(
              message.content,
              style: IOS26Theme.bodyLarge.copyWith(
                color: IOS26Theme.onPrimaryColor,
                height: 1.35,
              ),
            ),
            if (triggerHint != null) ...[
              const SizedBox(height: IOS26Theme.spacingXs),
              Text(
                triggerHint,
                style: IOS26Theme.bodySmall.copyWith(
                  color: IOS26Theme.onPrimaryColor.withValues(alpha: 0.7),
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAiBubble(
    BuildContext context,
    AppLocalizations l10n,
    double maxWidth,
  ) {
    final errorData = _resolveErrorData(message.metadata);
    final isErrorMessage = errorData != null;
    final thinking =
        ((message.metadata ??
                    const {})[XiaoMiChatService.assistantThinkingMetadataKey]
                as String?)
            ?.trim() ??
        '';

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: GlassContainer(
        borderRadius: IOS26Theme.radiusLg,
        padding: const EdgeInsets.fromLTRB(
          IOS26Theme.spacingMd,
          IOS26Theme.spacingSm,
          IOS26Theme.spacingMd,
          IOS26Theme.spacingSm,
        ),
        color: isErrorMessage
            ? IOS26Theme.toolRed.withValues(alpha: 0.08)
            : IOS26Theme.surfaceColor.withValues(alpha: 0.7),
        border: Border.all(
          color: selected
              ? IOS26Theme.primaryColor.withValues(alpha: 0.5)
              : (isErrorMessage
                    ? IOS26Theme.toolRed.withValues(alpha: 0.3)
                    : IOS26Theme.glassBorderColor.withValues(alpha: 0.4)),
          width: selected ? 1.5 : 0.5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectionMode && message.id != null) ...[
              IOS26Icon(
                selected
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.circle,
                size: 16,
                tone: IOS26IconTone.accent,
              ),
              const SizedBox(height: IOS26Theme.spacingXs),
            ],
            if (isErrorMessage)
              _buildErrorContent(l10n, errorData)
            else
              IOS26MarkdownBody(data: message.content),
            if (!isErrorMessage && thinking.isNotEmpty) ...[
              const SizedBox(height: IOS26Theme.spacingSm),
              ChatThinkingPanel(thinking: thinking),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorContent(
    AppLocalizations l10n,
    _MessageErrorData errorData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IOS26Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              size: 14,
              tone: IOS26IconTone.danger,
            ),
            const SizedBox(width: IOS26Theme.spacingXs),
            Expanded(
              child: SelectableText(
                message.content,
                style: IOS26Theme.bodyMedium.copyWith(
                  color: IOS26Theme.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        if (errorData.reason.isNotEmpty) ...[
          const SizedBox(height: IOS26Theme.spacingSm),
          _ErrorReasonPanel(reason: errorData.reason),
        ],
      ],
    );
  }

  String? _resolveTriggerHint(AppLocalizations l10n, String? presetId) {
    if (presetId == null || presetId.trim().isEmpty) return null;
    return switch (presetId) {
      'work_log_year_summary' =>
        l10n.xiao_mi_message_trigger_work_log_year_summary,
      _ => l10n.xiao_mi_message_trigger_custom,
    };
  }

  _MessageErrorData? _resolveErrorData(Map<String, dynamic>? metadata) {
    final value =
        (metadata ??
        const <String, dynamic>{})[XiaoMiChatService.assistantErrorMetadataKey];
    if (value is! Map) return null;
    final map = value.cast<Object?, Object?>();
    final reason = (map['reason']?.toString() ?? '').trim();
    if (reason.isEmpty) return null;
    return _MessageErrorData(reason: reason);
  }
}

class _MessageErrorData {
  final String reason;

  const _MessageErrorData({required this.reason});
}

class _ErrorReasonPanel extends StatefulWidget {
  final String reason;

  const _ErrorReasonPanel({required this.reason});

  @override
  State<_ErrorReasonPanel> createState() => _ErrorReasonPanelState();
}

class _ErrorReasonPanelState extends State<_ErrorReasonPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IOS26Icon(
                CupertinoIcons.info_circle,
                size: 14,
                tone: IOS26IconTone.danger,
              ),
              const SizedBox(width: IOS26Theme.spacingXs),
              Text(
                '查看错误原因',
                style: IOS26Theme.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: IOS26Theme.toolRed,
                ),
              ),
              const SizedBox(width: 4),
              IOS26Icon(
                _expanded
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
                size: 12,
                tone: IOS26IconTone.secondary,
              ),
            ],
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(top: IOS26Theme.spacingSm),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: IOS26Theme.toolRed.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              IOS26Theme.spacingSm,
              0,
              0,
              IOS26Theme.spacingXs,
            ),
            child: SelectableText(
              widget.reason,
              style: IOS26Theme.bodySmall.copyWith(
                color: IOS26Theme.textSecondary,
                height: 1.35,
              ),
            ),
          ),
      ],
    );
  }
}

class _CopyButton extends StatefulWidget {
  final VoidCallback onCopy;

  const _CopyButton({required this.onCopy});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  void _handleTap() {
    widget.onCopy();
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: IOS26Theme.spacingSm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: IOS26Theme.surfaceColor.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(IOS26Theme.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IOS26Icon(
              _copied ? CupertinoIcons.checkmark : CupertinoIcons.doc_on_doc,
              size: 10,
              color: _copied
                  ? IOS26Theme.primaryColor
                  : IOS26Theme.textTertiary,
            ),
            const SizedBox(width: 2),
            Text(
              _copied ? '已复制' : '复制',
              style: IOS26Theme.bodySmall.copyWith(
                fontSize: 10,
                color: _copied
                    ? IOS26Theme.primaryColor
                    : IOS26Theme.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
