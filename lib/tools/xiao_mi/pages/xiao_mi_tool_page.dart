import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/ai/ai_errors.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../core/ui/app_dialogs.dart';
import '../../../core/widgets/ios26_home_leading_button.dart';
import '../../../core/widgets/ios26_markdown.dart';
import '../../../core/widgets/ios26_sheet_header.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/ai_settings_page.dart';
import '../../../pages/home_page.dart';
import '../ai/xiao_mi_prompt_resolver.dart';
import '../models/xiao_mi_conversation.dart';
import '../models/xiao_mi_message.dart';
import '../services/xiao_mi_chat_service.dart';

class XiaoMiToolPage extends StatefulWidget {
  final XiaoMiChatService? service;

  const XiaoMiToolPage({super.key, this.service});

  @override
  State<XiaoMiToolPage> createState() => _XiaoMiToolPageState();
}

class _XiaoMiToolPageState extends State<XiaoMiToolPage> {
  late final XiaoMiChatService _service;
  late final bool _ownsService;

  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _ownsService = widget.service == null;
    _service =
        widget.service ??
        XiaoMiChatService(aiService: context.read<AiService>());
    _scrollController.addListener(_handleScroll);
    Future.microtask(() => _service.init());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _inputFocusNode.dispose();
    _inputController.dispose();
    if (_ownsService) {
      _service.dispose();
    }
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final shouldShow = position.maxScrollExtent - position.pixels > 240;
    if (shouldShow == _showScrollToBottom) return;
    setState(() => _showScrollToBottom = shouldShow);
  }

  void _navigateToHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      CupertinoPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  Future<void> _scrollToBottom({bool animated = true}) async {
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    if (!animated) {
      _scrollController.jumpTo(max);
      return;
    }
    await _scrollController.animateTo(
      max,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _send() async {
    final text = _inputController.text;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _inputController.clear();
    unawaited(_scrollToBottom(animated: true));

    try {
      await _service.send(trimmed);
      if (!mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      if (!mounted) return;
      unawaited(_scrollToBottom(animated: true));
    } on AiNotConfiguredException {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final go = await AppDialogs.showConfirm(
        context,
        title: l10n.xiao_mi_ai_not_configured_title,
        content: l10n.xiao_mi_ai_not_configured_content,
        cancelText: l10n.common_cancel,
        confirmText: l10n.common_go_settings,
      );
      if (!mounted || !go) return;
      Navigator.of(
        context,
      ).push(CupertinoPageRoute(builder: (_) => const AiSettingsPage()));
      _inputController.text = text;
    } on XiaoMiNoWorkLogDataException catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      await AppDialogs.showInfo(
        context,
        title: l10n.xiao_mi_no_work_log_title,
        content: l10n.xiao_mi_no_work_log_content,
        buttonText: l10n.common_ok,
      );
      _inputController.text = text;
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      await AppDialogs.showInfo(
        context,
        title: l10n.xiao_mi_send_failed_title,
        content: l10n.xiao_mi_send_failed_content(e.toString()),
        buttonText: l10n.common_ok,
      );
      _inputController.text = text;
    }
  }

  Future<void> _openConversationSheet() async {
    final selected = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        return ChangeNotifierProvider.value(
          value: _service,
          child: _XiaoMiConversationSheet(
            title: l10n.xiao_mi_conversations_title,
            newChatText: l10n.xiao_mi_new_chat,
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    if (selected == _XiaoMiConversationSheet.newChatSentinel) {
      await _service.newConversation();
      await _scrollToBottom(animated: false);
      return;
    }
    await _service.openConversation(selected);
    await _scrollToBottom(animated: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ChangeNotifierProvider.value(
      value: _service,
      child: Scaffold(
        backgroundColor: IOS26Theme.backgroundColor,
        resizeToAvoidBottomInset: true,
        body: BackdropGroup(
          child: Stack(
            children: [
              Positioned(
                top: -80,
                left: -80,
                child: _GlowCircle(
                  size: 240,
                  colors: [
                    IOS26Theme.toolPink.withValues(alpha: 0.16),
                    IOS26Theme.toolPink.withValues(alpha: 0.0),
                  ],
                ),
              ),
              Positioned(
                bottom: -110,
                right: -110,
                child: _GlowCircle(
                  size: 280,
                  colors: [
                    IOS26Theme.toolPurple.withValues(alpha: 0.12),
                    IOS26Theme.toolPurple.withValues(alpha: 0.0),
                  ],
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Consumer<XiaoMiChatService>(
                      builder: (context, service, _) {
                        final title = service.currentConversation?.title.trim();
                        return IOS26AppBar(
                          title: (title == null || title.isEmpty)
                              ? l10n.xiao_mi_title
                              : title,
                          useSafeArea: false,
                          leading: IOS26HomeLeadingButton(
                            onPressed: () => _navigateToHome(context),
                          ),
                          actions: [
                            IOS26IconButton(
                              icon: CupertinoIcons.list_bullet,
                              semanticLabel:
                                  l10n.xiao_mi_conversations_open_semantic,
                              onPressed: _openConversationSheet,
                              tone: IOS26IconTone.accent,
                            ),
                            IOS26IconButton(
                              icon: CupertinoIcons.add_circled_solid,
                              semanticLabel: l10n.xiao_mi_new_chat_semantic,
                              onPressed: service.sending
                                  ? null
                                  : () => service.newConversation(),
                              tone: IOS26IconTone.accent,
                            ),
                            const SizedBox(width: IOS26Theme.spacingXs),
                          ],
                        );
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(child: _buildMessageList(l10n)),
                          _buildInputBar(l10n),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_showScrollToBottom)
                Positioned(
                  right: IOS26Theme.spacingXl,
                  bottom: 110,
                  child: IOS26IconButton(
                    icon: CupertinoIcons.arrow_down,
                    semanticLabel: l10n.xiao_mi_scroll_to_bottom_semantic,
                    onPressed: () => _scrollToBottom(animated: true),
                    tone: IOS26IconTone.accent,
                    style: IOS26IconButtonStyle.chip,
                    padding: const EdgeInsets.all(IOS26Theme.spacingSm),
                    borderRadius: BorderRadius.circular(IOS26Theme.radiusFull),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(AppLocalizations l10n) {
    return Consumer<XiaoMiChatService>(
      builder: (context, service, _) {
        final messages = service.messages;
        if (messages.isEmpty) {
          return ListView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              IOS26Theme.spacingXl,
              IOS26Theme.spacingMd,
              IOS26Theme.spacingXl,
              IOS26Theme.spacingXl,
            ),
            children: [
              _WelcomePanel(
                title: l10n.xiao_mi_empty_title,
                subtitle: l10n.xiao_mi_empty_subtitle,
                prompts: service.quickPrompts,
                onTapPrompt: (prompt) {
                  _inputController.text = prompt.text;
                  FocusScope.of(context).requestFocus(_inputFocusNode);
                },
              ),
            ],
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (!_scrollController.hasClients) return;
          if (!_showScrollToBottom) {
            unawaited(_scrollToBottom(animated: true));
          }
        });

        return ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            IOS26Theme.spacingXl,
            IOS26Theme.spacingMd,
            IOS26Theme.spacingXl,
            IOS26Theme.spacingMd,
          ),
          itemCount:
              messages.length +
              ((service.sending && !service.hasStreamingAssistantDraft)
                  ? 1
                  : 0),
          itemBuilder: (context, index) {
            if (index >= messages.length) {
              return const _TypingIndicator();
            }
            return _MessageBubble(message: messages[index]);
          },
        );
      },
    );
  }

  Widget _buildInputBar(AppLocalizations l10n) {
    return Consumer<XiaoMiChatService>(
      builder: (context, service, _) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              IOS26Theme.spacingXl,
              IOS26Theme.spacingSm,
              IOS26Theme.spacingXl,
              IOS26Theme.spacingSm,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: IOS26Theme.surfaceColor.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(IOS26Theme.radiusXl),
                border: Border.all(
                  color: IOS26Theme.glassBorderColor,
                  width: 0.8,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                IOS26Theme.spacingSm,
                IOS26Theme.spacingSm,
                IOS26Theme.spacingSm,
                IOS26Theme.spacingSm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _inputController,
                      focusNode: _inputFocusNode,
                      placeholder: l10n.xiao_mi_input_placeholder,
                      maxLines: 5,
                      minLines: 1,
                      decoration: IOS26Theme.textFieldDecoration(),
                      style: IOS26Theme.bodyLarge,
                      enabled: !service.sending,
                    ),
                  ),
                  const SizedBox(width: IOS26Theme.spacingSm),
                  IOS26Button(
                    onPressed: service.sending ? null : _send,
                    variant: IOS26ButtonVariant.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: IOS26Theme.spacingLg,
                      vertical: IOS26Theme.spacingSm,
                    ),
                    child: service.sending
                        ? const CupertinoActivityIndicator()
                        : IOS26ButtonLabel(l10n.xiao_mi_send),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _GlowCircle({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<XiaoMiQuickPrompt> prompts;
  final ValueChanged<XiaoMiQuickPrompt> onTapPrompt;

  const _WelcomePanel({
    required this.title,
    required this.subtitle,
    required this.prompts,
    required this.onTapPrompt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        IOS26Theme.spacingSm,
        IOS26Theme.spacingXxl,
        IOS26Theme.spacingSm,
        IOS26Theme.spacingXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: IOS26Theme.displayLarge.copyWith(
              color: IOS26Theme.textPrimary,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: IOS26Theme.spacingSm),
          Text(
            subtitle,
            style: IOS26Theme.bodyMedium.copyWith(
              color: IOS26Theme.textSecondary,
              height: 1.4,
            ),
          ),
          if (prompts.isNotEmpty) ...[
            const SizedBox(height: IOS26Theme.spacingLg),
            Wrap(
              spacing: IOS26Theme.spacingSm,
              runSpacing: IOS26Theme.spacingSm,
              children: prompts
                  .map(
                    (prompt) => _QuickPromptChip(
                      prompt: prompt,
                      onTap: () => onTapPrompt(prompt),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: IOS26Theme.spacingSm,
        horizontal: IOS26Theme.spacingSm,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(width: IOS26Theme.spacingXs),
            Text(
              '思考中…',
              style: IOS26Theme.bodySmall.copyWith(
                color: IOS26Theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final XiaoMiMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == XiaoMiMessageRole.user;
    final maxWidth = MediaQuery.sizeOf(context).width * (isUser ? 0.74 : 0.90);
    final userBg = IOS26Theme.primaryColor.withValues(alpha: 0.13);
    final userBorder = IOS26Theme.primaryColor.withValues(alpha: 0.20);
    final fg = IOS26Theme.textPrimary;

    final presetId = (message.metadata ?? const {})['presetId'] as String?;
    final thinking =
        ((message.metadata ??
                    const {})[XiaoMiChatService.assistantThinkingMetadataKey]
                as String?)
            ?.trim() ??
        '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: IOS26Theme.spacingXs),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isUser ? userBg : Colors.transparent,
              borderRadius: BorderRadius.circular(
                isUser ? IOS26Theme.radiusXl : IOS26Theme.radiusMd,
              ),
              border: isUser ? Border.all(color: userBorder, width: 0.8) : null,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                IOS26Theme.spacingMd,
                IOS26Theme.spacingSm,
                IOS26Theme.spacingMd,
                IOS26Theme.spacingSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (presetId != null &&
                      presetId.trim().isNotEmpty &&
                      isUser) ...[
                    _PresetBadge(presetId: presetId),
                    const SizedBox(height: IOS26Theme.spacingXs),
                  ],
                  if (isUser)
                    SelectableText(
                      message.content,
                      style: IOS26Theme.bodyLarge.copyWith(
                        color: fg,
                        height: 1.35,
                      ),
                    )
                  else
                    IOS26MarkdownBody(data: message.content),
                  if (!isUser && thinking.isNotEmpty) ...[
                    const SizedBox(height: IOS26Theme.spacingSm),
                    _ThinkingPanel(thinking: thinking),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingPanel extends StatefulWidget {
  final String thinking;

  const _ThinkingPanel({required this.thinking});

  @override
  State<_ThinkingPanel> createState() => _ThinkingPanelState();
}

class _ThinkingPanelState extends State<_ThinkingPanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IOS26Button.plain(
          padding: const EdgeInsets.symmetric(
            horizontal: 0,
            vertical: IOS26Theme.spacingXs,
          ),
          onPressed: () => setState(() => _expanded = !_expanded),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IOS26Icon(
                CupertinoIcons.lightbulb,
                tone: IOS26IconTone.accent,
                size: 15,
              ),
              const SizedBox(width: IOS26Theme.spacingXs),
              Text(
                '思考过程',
                style: IOS26Theme.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: IOS26Theme.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              IOS26Icon(
                _expanded
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
                tone: IOS26IconTone.secondary,
                size: 12,
              ),
            ],
          ),
        ),
        if (_expanded)
          Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: IOS26Theme.textTertiary.withValues(alpha: 0.6),
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
            child: IOS26MarkdownBody(data: widget.thinking),
          ),
      ],
    );
  }
}

class _PresetBadge extends StatelessWidget {
  final String presetId;

  const _PresetBadge({required this.presetId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (presetId) {
      'work_log_year_summary' => l10n.xiao_mi_preset_work_log_year_summary,
      _ => l10n.xiao_mi_preset_custom,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: IOS26Theme.toolPurple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(IOS26Theme.radiusFull),
        border: Border.all(
          color: IOS26Theme.toolPurple.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: IOS26Theme.spacingSm,
          vertical: 6,
        ),
        child: Text(
          label,
          style: IOS26Theme.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: IOS26Theme.toolPurple,
          ),
        ),
      ),
    );
  }
}

class _QuickPromptChip extends StatelessWidget {
  final XiaoMiQuickPrompt prompt;
  final VoidCallback onTap;

  const _QuickPromptChip({required this.prompt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: IOS26Theme.surfaceColor.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(IOS26Theme.radiusFull),
        border: Border.all(
          color: IOS26Theme.textTertiary.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: IOS26Button.plain(
        padding: const EdgeInsets.symmetric(
          horizontal: IOS26Theme.spacingMd,
          vertical: 6,
        ),
        minimumSize: IOS26Theme.minimumTapSize,
        onPressed: onTap,
        child: Text(
          prompt.text,
          style: IOS26Theme.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: IOS26Theme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _XiaoMiConversationSheet extends StatelessWidget {
  static const int newChatSentinel = -1;

  final String title;
  final String newChatText;

  const _XiaoMiConversationSheet({
    required this.title,
    required this.newChatText,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(IOS26Theme.radiusXl),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: IOS26Theme.surfaceColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IOS26SheetHeader(
                    title: title,
                    cancelText: AppLocalizations.of(context)!.common_close,
                    doneText: newChatText,
                    onDone: () => Navigator.pop(context, newChatSentinel),
                  ),
                  Flexible(
                    child: Consumer<XiaoMiChatService>(
                      builder: (context, service, _) {
                        final items = service.conversations;
                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(IOS26Theme.spacingXl),
                            child: Text(
                              AppLocalizations.of(
                                context,
                              )!.xiao_mi_conversations_empty,
                              style: IOS26Theme.bodyMedium.copyWith(
                                color: IOS26Theme.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            IOS26Theme.spacingXl,
                            IOS26Theme.spacingSm,
                            IOS26Theme.spacingXl,
                            IOS26Theme.spacingXl,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => Container(
                            height: 0.5,
                            margin: const EdgeInsets.symmetric(
                              horizontal: IOS26Theme.spacingSm,
                            ),
                            color: IOS26Theme.textTertiary.withValues(
                              alpha: 0.22,
                            ),
                          ),
                          itemBuilder: (context, index) {
                            final convo = items[index];
                            return _ConversationRow(conversation: convo);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final XiaoMiConversation conversation;

  const _ConversationRow({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final service = context.read<XiaoMiChatService>();
    final l10n = AppLocalizations.of(context)!;
    final currentId = service.currentConversation?.id;
    final selected = currentId != null && currentId == conversation.id;
    final title = conversation.title.trim().isEmpty
        ? l10n.xiao_mi_new_chat
        : conversation.title.trim();

    return GlassContainer(
      padding: EdgeInsets.zero,
      child: IOS26Button.plain(
        padding: EdgeInsets.zero,
        onPressed: () => Navigator.pop(context, conversation.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            IOS26Theme.spacingMd,
            IOS26Theme.spacingMd,
            IOS26Theme.spacingMd,
            IOS26Theme.spacingMd,
          ),
          child: Row(
            children: [
              const IOS26Icon(
                CupertinoIcons.chat_bubble_2_fill,
                tone: IOS26IconTone.accent,
                size: 20,
              ),
              const SizedBox(width: IOS26Theme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: IOS26Theme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: IOS26Theme.spacingXs),
                    Text(
                      _formatTime(conversation.updatedAt),
                      style: IOS26Theme.bodySmall.copyWith(
                        color: IOS26Theme.textSecondary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                IOS26Icon(
                  CupertinoIcons.checkmark_circle_fill,
                  color: IOS26Theme.primaryColor,
                  size: 20,
                ),
              const SizedBox(width: IOS26Theme.spacingXs),
              IOS26IconButton(
                icon: CupertinoIcons.ellipsis,
                semanticLabel: l10n.xiao_mi_conversation_more_semantic,
                onPressed: () => _openActions(context, conversation),
                tone: IOS26IconTone.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}';
  }

  Future<void> _openActions(
    BuildContext context,
    XiaoMiConversation convo,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<XiaoMiChatService>();

    final action = await AppDialogs.showActionSheet<String>(
      context,
      title: l10n.xiao_mi_conversation_actions_title,
      actions: [
        CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context, 'rename'),
          child: Text(l10n.common_rename),
        ),
        CupertinoActionSheetAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(context, 'delete'),
          child: Text(l10n.common_delete),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.common_cancel),
      ),
    );
    if (!context.mounted) return;

    if (action == 'rename') {
      final title = await AppDialogs.showInput(
        context,
        title: l10n.xiao_mi_conversation_rename_title,
        placeholder: l10n.xiao_mi_conversation_rename_placeholder,
        defaultValue: convo.title,
        cancelText: l10n.common_cancel,
        confirmText: l10n.common_save,
      );
      if (!context.mounted) return;
      if (title == null) return;
      await service.renameConversation(conversationId: convo.id!, title: title);
      return;
    }

    if (action == 'delete') {
      final ok = await AppDialogs.showConfirm(
        context,
        title: l10n.xiao_mi_conversation_delete_title,
        content: l10n.xiao_mi_conversation_delete_content,
        cancelText: l10n.common_cancel,
        confirmText: l10n.common_delete,
        isDestructive: true,
      );
      if (!context.mounted) return;
      if (!ok) return;
      await service.deleteConversation(convo.id!);
    }
  }
}
