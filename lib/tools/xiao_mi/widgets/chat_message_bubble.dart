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
  final VoidCallback onExport;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.selectionMode,
    required this.selected,
    this.showAvatar = true,
    required this.onTap,
    required this.onLongPress,
    required this.onCopy,
    required this.onExport,
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
        child: isUser
            ? _buildUserLayout(context, l10n)
            : _buildAssistantLayout(context, l10n),
      ),
    );
  }

  Widget _buildUserLayout(BuildContext context, AppLocalizations l10n) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.75;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Spacer(),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildUserBubble(l10n),
              if (!selectionMode) ...[
                const SizedBox(height: 2),
                _MessageActions(onCopy: onCopy),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantLayout(BuildContext context, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showAvatar) ...[
          _buildAiAvatar(),
          const SizedBox(width: IOS26Theme.spacingSm),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAiContent(context, l10n),
              if (!selectionMode) ...[
                const SizedBox(height: 2),
                _MessageActions(onCopy: onCopy, onExport: onExport),
              ],
            ],
          ),
        ),
      ],
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

  Widget _buildUserBubble(AppLocalizations l10n) {
    final triggerHint = _resolveTriggerHint(l10n, message.metadata);

    return Container(
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
    );
  }

  Widget _buildAiContent(BuildContext context, AppLocalizations l10n) {
    final errorData = _resolveErrorData(message.metadata);
    final isErrorMessage = errorData != null;
    final usageData = _resolveUsageData(message.metadata);
    final thinking =
        ((message.metadata ??
                    const {})[XiaoMiChatService.assistantThinkingMetadataKey]
                as String?)
            ?.trim() ??
        '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        IOS26Theme.spacingSm,
        IOS26Theme.spacingXs,
        0,
        IOS26Theme.spacingXs,
      ),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: selected
                ? IOS26Theme.primaryColor.withValues(alpha: 0.6)
                : (isErrorMessage
                      ? IOS26Theme.toolRed.withValues(alpha: 0.4)
                      : IOS26Theme.textTertiary.withValues(alpha: 0.28)),
            width: selected ? 2 : 1,
          ),
        ),
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
          if (!isErrorMessage && usageData != null) ...[
            const SizedBox(height: IOS26Theme.spacingSm),
            _MessageUsageFooter(data: usageData),
          ],
        ],
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

  String? _resolveTriggerHint(
    AppLocalizations l10n,
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null) return null;
    final startDate = metadata['queryStartDate'] as String?;
    final endDate = metadata['queryEndDate'] as String?;
    if (startDate != null && endDate != null) {
      return l10n.xiao_mi_message_trigger_work_log_range(startDate, endDate);
    }
    final triggerSource = metadata['triggerSource'] as String?;
    if (triggerSource != null && triggerSource.isNotEmpty) {
      return l10n.xiao_mi_message_trigger_custom;
    }
    return null;
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

  _MessageUsageData? _resolveUsageData(Map<String, dynamic>? metadata) {
    final value =
        (metadata ??
        const <String, dynamic>{})[XiaoMiChatService.assistantUsageMetadataKey];
    if (value is! Map) return null;
    final map = value.cast<Object?, Object?>();
    final data = _MessageUsageData(
      promptTokens: _readInt(map['promptTokens']),
      completionTokens: _readInt(map['completionTokens']),
      totalTokens: _readInt(map['totalTokens']),
      durationMs: _readInt(map['durationMs']),
    );
    return data.isEmpty ? null : data;
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

class _MessageErrorData {
  final String reason;

  const _MessageErrorData({required this.reason});
}

class _MessageUsageData {
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final int? durationMs;

  const _MessageUsageData({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.durationMs,
  });

  bool get isEmpty =>
      promptTokens == null &&
      completionTokens == null &&
      totalTokens == null &&
      durationMs == null;
}

class _MessageUsageFooter extends StatelessWidget {
  final _MessageUsageData data;

  const _MessageUsageFooter({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = <_UsageMetricData>[
      if (data.promptTokens != null)
        _UsageMetricData(
          icon: CupertinoIcons.arrow_up_circle,
          label: '上送',
          value: _formatNumber(data.promptTokens!),
        ),
      if (data.completionTokens != null)
        _UsageMetricData(
          icon: CupertinoIcons.arrow_down_circle,
          label: '输出',
          value: _formatNumber(data.completionTokens!),
        ),
      if (data.totalTokens != null)
        _UsageMetricData(
          icon: CupertinoIcons.number,
          label: '总计',
          value: _formatNumber(data.totalTokens!),
        ),
      if (data.durationMs != null)
        _UsageMetricData(
          icon: CupertinoIcons.timer,
          label: '耗时',
          value: _formatDuration(data.durationMs!),
        ),
    ];

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map((item) => _UsageMetricChip(item: item))
          .toList(growable: false),
    );
  }

  static String _formatNumber(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i += 1) {
      final remaining = raw.length - i;
      buffer.write(raw[i]);
      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  static String _formatDuration(int milliseconds) {
    if (milliseconds < 1000) {
      return '${milliseconds}ms';
    }
    final seconds = milliseconds / 1000;
    if (seconds < 10) {
      return '${seconds.toStringAsFixed(1)}s';
    }
    final totalSeconds = seconds.round();
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    }
    final minutes = totalSeconds ~/ 60;
    final remainSeconds = totalSeconds % 60;
    return '${minutes}m ${remainSeconds}s';
  }
}

class _UsageMetricData {
  final IconData icon;
  final String label;
  final String value;

  const _UsageMetricData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _UsageMetricChip extends StatelessWidget {
  final _UsageMetricData item;

  const _UsageMetricChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final foreground = IOS26Theme.textSecondary;
    final border = IOS26Theme.textTertiary.withValues(
      alpha: IOS26Theme.isDarkMode ? 0.34 : 0.24,
    );
    final background = IOS26Theme.surfaceVariant.withValues(
      alpha: IOS26Theme.isDarkMode ? 0.34 : 0.42,
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(IOS26Theme.radiusSm),
        border: Border.all(color: border, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IOS26Icon(item.icon, size: 11, color: foreground),
          const SizedBox(width: 4),
          Text(
            '${item.label} ${item.value}',
            style: IOS26Theme.bodySmall.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: foreground,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
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

class _MessageActions extends StatelessWidget {
  final VoidCallback onCopy;
  final VoidCallback? onExport;

  const _MessageActions({required this.onCopy, this.onExport});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CopyButton(onCopy: onCopy),
        if (onExport != null) ...[
          const SizedBox(width: IOS26Theme.spacingXs),
          _ExportButton(onExport: onExport!),
        ],
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
    return _MessageActionChip(
      chipKey: const ValueKey('xiao_mi_copy_action_chip'),
      icon: _copied ? CupertinoIcons.checkmark : CupertinoIcons.doc_on_doc,
      label: _copied ? '已复制' : '复制',
      active: _copied,
      onTap: _handleTap,
    );
  }
}

class _ExportButton extends StatelessWidget {
  final VoidCallback onExport;

  const _ExportButton({required this.onExport});

  @override
  Widget build(BuildContext context) {
    return _MessageActionChip(
      chipKey: const ValueKey('xiao_mi_export_action_chip'),
      icon: CupertinoIcons.arrow_up_doc,
      label: '导出',
      onTap: onExport,
    );
  }
}

class _MessageActionChip extends StatelessWidget {
  final Key? chipKey;
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _MessageActionChip({
    this.chipKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final variant = active
        ? IOS26ButtonVariant.secondary
        : IOS26ButtonVariant.neutral;
    final colors = IOS26Theme.buttonColors(variant);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: chipKey,
        constraints: const BoxConstraints(minHeight: 30),
        padding: const EdgeInsets.symmetric(
          horizontal: IOS26Theme.spacingMd,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
          border: Border.all(
            color: colors.border.withValues(alpha: active ? 0.82 : 0.58),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IOS26Icon(icon, size: 12, color: colors.foreground),
            const SizedBox(width: IOS26Theme.spacingXs),
            Text(
              label,
              style: IOS26Theme.bodySmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
