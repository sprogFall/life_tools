import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/ai/ai_service.dart';
import '../../../core/theme/ios26_theme.dart';
import '../../../core/ui/app_dialogs.dart';
import '../../../core/utils/dev_log.dart';
import '../../../core/widgets/ios26_home_leading_button.dart';
import '../../../core/widgets/ios26_sheet_header.dart';
import '../../../core/widgets/ios26_toast.dart';
import '../../../l10n/app_localizations.dart';
import '../../../pages/home_page.dart';
import '../ai/xiao_mi_prompt_resolver.dart';
import '../models/xiao_mi_conversation.dart';
import '../models/xiao_mi_message.dart';
import '../services/xiao_mi_chat_service.dart';
import '../services/xiao_mi_message_export_service.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/chat_message_list.dart';

class XiaoMiToolPage extends StatefulWidget {
  final XiaoMiChatService? service;

  const XiaoMiToolPage({super.key, this.service});

  @override
  State<XiaoMiToolPage> createState() => _XiaoMiToolPageState();
}

class _XiaoMiToolPageState extends State<XiaoMiToolPage>
    with WidgetsBindingObserver {
  late final XiaoMiChatService _service;
  late final XiaoMiMessageExportService _messageExportService;
  late final bool _ownsService;

  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  bool _selectionMode = false;
  final Set<int> _selectedMessageIds = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsService = widget.service == null;
    _service =
        widget.service ??
        XiaoMiChatService(aiService: context.read<AiService>());
    _messageExportService = XiaoMiMessageExportService();
    _scrollController.addListener(_handleScroll);
    Future.microtask(() => _service.init());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (!_showScrollToBottom && _service.messages.isNotEmpty) {
        _scrollToBottom(animated: false);
      }
    });
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
    final trimmed = _inputController.text.trim();
    if (trimmed.isEmpty) return;

    _inputController.clear();
    unawaited(_scrollToBottom(animated: true));

    await _service.send(trimmed);
    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    if (!mounted) return;
    unawaited(_scrollToBottom(animated: true));
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
    _exitSelectionMode();
    if (selected == _XiaoMiConversationSheet.newChatSentinel) {
      await _service.newConversation();
      await _scrollToBottom(animated: false);
      return;
    }
    await _service.openConversation(selected);
    await _scrollToBottom(animated: false);
  }

  void _onLongPressMessage(XiaoMiMessage message, XiaoMiChatService service) {
    if (service.sending) return;
    final messageId = message.id;
    if (messageId == null) return;

    setState(() {
      _selectionMode = true;
      _selectedMessageIds.add(messageId);
    });
  }

  void _onTapMessage(XiaoMiMessage message, XiaoMiChatService service) {
    if (!_selectionMode) return;
    final messageId = message.id;
    if (messageId == null) return;

    // 清理已过期的选中项
    _cleanupStaleSelections(service);

    setState(() {
      if (!_selectedMessageIds.add(messageId)) {
        _selectedMessageIds.remove(messageId);
      }
      if (_selectedMessageIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  /// 清理已不存在的选中项
  void _cleanupStaleSelections(XiaoMiChatService service) {
    final messages = service.messages;
    final availableIds = messages
        .map((message) => message.id)
        .whereType<int>()
        .toSet();
    final staleSelected = _selectedMessageIds.difference(availableIds);
    if (staleSelected.isNotEmpty) {
      _selectedMessageIds.removeAll(staleSelected);
      if (_selectedMessageIds.isEmpty) {
        _selectionMode = false;
      }
    }
  }

  void _exitSelectionMode() {
    if (!_selectionMode && _selectedMessageIds.isEmpty) return;
    setState(() {
      _selectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  Future<void> _copyMessageContent(String content) async {
    final text = content.trim();
    if (text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    context.read<ToastService>().showSuccess(
      l10n.xiao_mi_message_copy_done_content,
    );
  }

  Future<void> _exportMessage(XiaoMiMessage message) async {
    final text = message.content.trim();
    if (text.isEmpty) return;

    final format = await _pickExportFormat();
    if (!mounted || format == null) return;

    try {
      await _messageExportService.exportMessage(
        message: message,
        format: format,
      );
    } catch (error, stackTrace) {
      devLog(
        'xiao_mi_message_export_failed',
        error: error,
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      context.read<ToastService>().showError('导出失败，请稍后重试');
    }
  }

  Future<XiaoMiMessageExportFormat?> _pickExportFormat() {
    return showModalBottomSheet<XiaoMiMessageExportFormat>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _XiaoMiExportFormatSheet(),
    );
  }

  Future<void> _deleteSelectedMessages(XiaoMiChatService service) async {
    final selectedCount = _selectedMessageIds.length;
    if (selectedCount == 0) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialogs.showConfirm(
      context,
      title: l10n.xiao_mi_message_delete_selected_title,
      content: l10n.xiao_mi_message_delete_selected_content(selectedCount),
      cancelText: l10n.common_cancel,
      confirmText: l10n.common_delete,
      isDestructive: true,
    );
    if (!mounted || !confirmed) return;

    final ids = Set<int>.from(_selectedMessageIds);
    await service.deleteMessages(ids);
    if (!mounted) return;
    _exitSelectionMode();
  }

  void _onTapPrompt(XiaoMiQuickPrompt prompt) {
    _inputController.text = prompt.text;
    FocusScope.of(context).requestFocus(_inputFocusNode);
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
          child: Consumer<XiaoMiChatService>(
            builder: (context, service, _) {
              final title = service.currentConversation?.title.trim();
              final canCreateConversation =
                  !service.sending && service.messages.isNotEmpty;
              final selectedCount = _selectedMessageIds.length;

              return Stack(
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        IOS26AppBar(
                          title: _selectionMode
                              ? l10n.xiao_mi_message_selected_count(
                                  selectedCount,
                                )
                              : ((title == null || title.isEmpty)
                                    ? l10n.xiao_mi_title
                                    : title),
                          useSafeArea: false,
                          leading: IOS26HomeLeadingButton(
                            onPressed: () => _navigateToHome(context),
                          ),
                          actions: _selectionMode
                              ? [
                                  IOS26IconButton(
                                    icon: CupertinoIcons.delete,
                                    semanticLabel: l10n.common_delete,
                                    onPressed: selectedCount > 0
                                        ? () => _deleteSelectedMessages(service)
                                        : null,
                                    tone: IOS26IconTone.secondary,
                                  ),
                                  IOS26IconButton(
                                    icon: CupertinoIcons.clear_circled_solid,
                                    semanticLabel: l10n.common_close,
                                    onPressed: _exitSelectionMode,
                                    tone: IOS26IconTone.secondary,
                                  ),
                                  const SizedBox(width: IOS26Theme.spacingXs),
                                ]
                              : [
                                  IOS26IconButton(
                                    icon: CupertinoIcons.list_bullet,
                                    semanticLabel: l10n
                                        .xiao_mi_conversations_open_semantic,
                                    onPressed: _openConversationSheet,
                                    tone: IOS26IconTone.accent,
                                  ),
                                  IOS26IconButton(
                                    icon: CupertinoIcons.add_circled_solid,
                                    semanticLabel:
                                        l10n.xiao_mi_new_chat_semantic,
                                    onPressed: canCreateConversation
                                        ? () => service.newConversation()
                                        : null,
                                    tone: IOS26IconTone.accent,
                                  ),
                                  const SizedBox(width: IOS26Theme.spacingXs),
                                ],
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: ChatMessageList(
                                  scrollController: _scrollController,
                                  showScrollToBottom: _showScrollToBottom,
                                  onScrollToBottom: () =>
                                      _scrollToBottom(animated: true),
                                  onLongPressMessage: _onLongPressMessage,
                                  onTapMessage: (message) =>
                                      _onTapMessage(message, service),
                                  onCopyMessage: _copyMessageContent,
                                  onExportMessage: _exportMessage,
                                  onTapPrompt: _onTapPrompt,
                                  selectionMode: _selectionMode,
                                  selectedMessageIds: _selectedMessageIds,
                                ),
                              ),
                              if (!_selectionMode)
                                ChatInputBar(
                                  controller: _inputController,
                                  focusNode: _inputFocusNode,
                                  sending: service.sending,
                                  onSend: _send,
                                ),
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
                        borderRadius: BorderRadius.circular(
                          IOS26Theme.radiusFull,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _XiaoMiExportFormatSheet extends StatefulWidget {
  const _XiaoMiExportFormatSheet();

  @override
  State<_XiaoMiExportFormatSheet> createState() =>
      _XiaoMiExportFormatSheetState();
}

class _XiaoMiExportFormatSheetState extends State<_XiaoMiExportFormatSheet> {
  XiaoMiMessageExportFormat _selectedFormat =
      XiaoMiMessageExportFormat.markdown;

  void _submit() {
    Navigator.pop(context, _selectedFormat);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          IOS26Theme.spacingMd,
          0,
          IOS26Theme.spacingMd,
          bottomInset + IOS26Theme.spacingMd,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(IOS26Theme.radiusXl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                IOS26Theme.spacingXl,
                IOS26Theme.spacingLg,
                IOS26Theme.spacingXl,
                IOS26Theme.spacingXl,
              ),
              color: IOS26Theme.surfaceColor.withValues(alpha: 0.98),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '导出为',
                        style: IOS26Theme.titleMedium.copyWith(
                          color: IOS26Theme.textPrimary,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IOS26IconButton(
                          icon: CupertinoIcons.xmark,
                          semanticLabel: AppLocalizations.of(
                            context,
                          )!.common_close,
                          onPressed: () => Navigator.pop(context),
                          tone: IOS26IconTone.secondary,
                          style: IOS26IconButtonStyle.chip,
                          padding: const EdgeInsets.all(IOS26Theme.spacingXs),
                          minimumSize: const Size(32, 32),
                          size: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: IOS26Theme.spacingLg),
                  Row(
                    children: [
                      Expanded(
                        child: _ExportFormatOptionCard(
                          icon: CupertinoIcons.doc_plaintext,
                          label: 'TXT 文件',
                          selected:
                              _selectedFormat == XiaoMiMessageExportFormat.text,
                          onTap: () => setState(
                            () => _selectedFormat =
                                XiaoMiMessageExportFormat.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: IOS26Theme.spacingMd),
                      Expanded(
                        child: _ExportFormatOptionCard(
                          icon: CupertinoIcons.doc_text,
                          label: 'Markdown',
                          selected:
                              _selectedFormat ==
                              XiaoMiMessageExportFormat.markdown,
                          onTap: () => setState(
                            () => _selectedFormat =
                                XiaoMiMessageExportFormat.markdown,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: IOS26Theme.spacingXl),
                  SizedBox(
                    width: double.infinity,
                    child: IOS26Button(
                      onPressed: _submit,
                      variant: IOS26ButtonVariant.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
                      child: const IOS26ButtonLabel('导出'),
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

class _ExportFormatOptionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ExportFormatOptionCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = IOS26Theme.buttonColors(
      selected ? IOS26ButtonVariant.secondary : IOS26ButtonVariant.neutral,
    );
    return IOS26Button.plain(
      onPressed: onTap,
      borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
      padding: const EdgeInsets.symmetric(
        horizontal: IOS26Theme.spacingSm,
        vertical: IOS26Theme.spacingMd,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
          border: Border.all(
            color: colors.border.withValues(alpha: selected ? 0.9 : 0.56),
            width: selected ? 1.2 : 0.9,
          ),
        ),
        child: SizedBox(
          height: 90,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IOS26Icon(icon, size: 24, color: colors.foreground),
                const SizedBox(height: IOS26Theme.spacingSm),
                Text(
                  label,
                  style: IOS26Theme.bodySmall.copyWith(
                    color: colors.foreground,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _XiaoMiConversationSheet extends StatefulWidget {
  static const int newChatSentinel = -1;

  final String title;
  final String newChatText;

  const _XiaoMiConversationSheet({
    required this.title,
    required this.newChatText,
  });

  @override
  State<_XiaoMiConversationSheet> createState() =>
      _XiaoMiConversationSheetState();
}

class _XiaoMiConversationSheetState extends State<_XiaoMiConversationSheet> {
  bool _conversationSelectionMode = false;
  final Set<int> _selectedConversationIds = <int>{};

  void _onTapConversation(
    XiaoMiConversation conversation,
    XiaoMiChatService service,
  ) {
    final conversationId = conversation.id;
    if (conversationId == null) return;

    if (!_conversationSelectionMode) {
      Navigator.pop(context, conversationId);
      return;
    }

    _cleanupStaleConversationSelections(service);
    setState(() {
      if (!_selectedConversationIds.add(conversationId)) {
        _selectedConversationIds.remove(conversationId);
      }
      if (_selectedConversationIds.isEmpty) {
        _conversationSelectionMode = false;
      }
    });
  }

  void _onLongPressConversation(
    XiaoMiConversation conversation,
    XiaoMiChatService service,
  ) {
    if (service.sending) return;
    final conversationId = conversation.id;
    if (conversationId == null) return;

    _cleanupStaleConversationSelections(service);
    setState(() {
      _conversationSelectionMode = true;
      _selectedConversationIds.add(conversationId);
    });
  }

  void _cleanupStaleConversationSelections(XiaoMiChatService service) {
    final availableIds = service.conversations
        .map((conversation) => conversation.id)
        .whereType<int>()
        .toSet();
    final staleSelected = _selectedConversationIds.difference(availableIds);
    if (staleSelected.isEmpty) return;

    _selectedConversationIds.removeAll(staleSelected);
    if (_selectedConversationIds.isEmpty) {
      _conversationSelectionMode = false;
    }
  }

  void _exitConversationSelectionMode() {
    if (!_conversationSelectionMode && _selectedConversationIds.isEmpty) {
      return;
    }
    setState(() {
      _conversationSelectionMode = false;
      _selectedConversationIds.clear();
    });
  }

  Future<void> _deleteSelectedConversations(XiaoMiChatService service) async {
    final selectedCount = _selectedConversationIds.length;
    if (selectedCount == 0) return;

    final l10n = AppLocalizations.of(context)!;
    final confirmed = await AppDialogs.showConfirm(
      context,
      title: l10n.xiao_mi_conversation_delete_selected_title,
      content: l10n.xiao_mi_conversation_delete_selected_content(selectedCount),
      cancelText: l10n.common_cancel,
      confirmText: l10n.common_delete,
      isDestructive: true,
    );
    if (!mounted || !confirmed) return;

    final ids = Set<int>.from(_selectedConversationIds);
    await service.deleteConversations(ids);
    if (!mounted) return;
    _exitConversationSelectionMode();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.84;
    return SafeArea(
      top: true,
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
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: IOS26Theme.spacingSm),
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: IOS26Theme.textTertiary.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(
                          IOS26Theme.radiusFull,
                        ),
                      ),
                    ),
                    const SizedBox(height: IOS26Theme.spacingXs),
                    Consumer<XiaoMiChatService>(
                      builder: (context, service, _) {
                        _cleanupStaleConversationSelections(service);
                        final canCreateConversation =
                            !service.sending && service.messages.isNotEmpty;
                        final selectedCount = _selectedConversationIds.length;
                        if (_conversationSelectionMode) {
                          return IOS26SheetHeader(
                            title: AppLocalizations.of(context)!
                                .xiao_mi_conversation_selected_count(
                                  selectedCount,
                                ),
                            cancelText: AppLocalizations.of(
                              context,
                            )!.common_cancel,
                            doneText: AppLocalizations.of(
                              context,
                            )!.common_delete,
                            onCancel: _exitConversationSelectionMode,
                            onDone: selectedCount > 0
                                ? () => _deleteSelectedConversations(service)
                                : null,
                          );
                        }
                        const newChatSentinel =
                            _XiaoMiConversationSheet.newChatSentinel;
                        return IOS26SheetHeader(
                          title: widget.title,
                          cancelText: AppLocalizations.of(
                            context,
                          )!.common_close,
                          doneText: widget.newChatText,
                          onDone: canCreateConversation
                              ? () => Navigator.pop(context, newChatSentinel)
                              : null,
                        );
                      },
                    ),
                    Flexible(
                      child: Consumer<XiaoMiChatService>(
                        builder: (context, service, _) {
                          final items = service.conversations;
                          if (items.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(
                                IOS26Theme.spacingXl,
                              ),
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
                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(
                              IOS26Theme.spacingXl,
                              IOS26Theme.spacingSm,
                              IOS26Theme.spacingXl,
                              IOS26Theme.spacingXxl,
                            ),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final convo = items[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index == items.length - 1
                                      ? 0
                                      : IOS26Theme.spacingSm,
                                ),
                                child: _ConversationRow(
                                  conversation: convo,
                                  selectionMode: _conversationSelectionMode,
                                  selectedConversationIds:
                                      _selectedConversationIds,
                                  onTap: (conversation) =>
                                      _onTapConversation(conversation, service),
                                  onLongPress: (conversation) =>
                                      _onLongPressConversation(
                                        conversation,
                                        service,
                                      ),
                                ),
                              );
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
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final XiaoMiConversation conversation;
  final bool selectionMode;
  final Set<int> selectedConversationIds;
  final ValueChanged<XiaoMiConversation> onTap;
  final ValueChanged<XiaoMiConversation> onLongPress;

  const _ConversationRow({
    required this.conversation,
    required this.selectionMode,
    required this.selectedConversationIds,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<XiaoMiChatService>();
    final l10n = AppLocalizations.of(context)!;
    final currentId = service.currentConversation?.id;
    final conversationId = conversation.id;
    final selectedInSelectionMode =
        conversationId != null &&
        selectedConversationIds.contains(conversationId);
    final selectedInNormalMode =
        currentId != null && currentId == conversation.id;
    final selected = selectionMode
        ? selectedInSelectionMode
        : selectedInNormalMode;
    final titleText = conversation.title.trim();
    final title = titleText.isEmpty ? l10n.xiao_mi_new_chat : titleText;
    final tileBackground = selected
        ? IOS26Theme.primaryColor.withValues(alpha: 0.14)
        : IOS26Theme.surfaceColor.withValues(alpha: 0.72);
    final tileBorder = selected
        ? IOS26Theme.primaryColor.withValues(alpha: 0.34)
        : IOS26Theme.glassBorderColor.withValues(alpha: 0.75);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => onLongPress(conversation),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tileBackground,
          borderRadius: BorderRadius.circular(IOS26Theme.radiusLg),
          border: Border.all(color: tileBorder, width: 0.8),
        ),
        child: IOS26Button.plain(
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(IOS26Theme.radiusLg),
          onPressed: () => onTap(conversation),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              IOS26Theme.spacingMd,
              IOS26Theme.spacingMd,
              IOS26Theme.spacingSm,
              IOS26Theme.spacingMd,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? IOS26Theme.primaryColor.withValues(alpha: 0.18)
                        : IOS26Theme.surfaceColor.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(IOS26Theme.radiusMd),
                  ),
                  child: IOS26Icon(
                    CupertinoIcons.chat_bubble_2_fill,
                    tone: selected
                        ? IOS26IconTone.accent
                        : IOS26IconTone.secondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: IOS26Theme.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: IOS26Theme.titleSmall.copyWith(
                          color: IOS26Theme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: IOS26Theme.spacingXs),
                      Text(
                        _formatTime(conversation.updatedAt),
                        style: IOS26Theme.bodySmall.copyWith(
                          color: IOS26Theme.textSecondary.withValues(
                            alpha: 0.88,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected) ...[
                  IOS26Icon(
                    CupertinoIcons.checkmark_circle_fill,
                    color: IOS26Theme.primaryColor,
                    size: 18,
                  ),
                  const SizedBox(width: IOS26Theme.spacingXs),
                ],
                if (!selectionMode)
                  IOS26IconButton(
                    icon: CupertinoIcons.ellipsis,
                    semanticLabel: l10n.xiao_mi_conversation_more_semantic,
                    onPressed: () => _openActions(context, conversation),
                    tone: IOS26IconTone.secondary,
                    size: 18,
                  ),
              ],
            ),
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
