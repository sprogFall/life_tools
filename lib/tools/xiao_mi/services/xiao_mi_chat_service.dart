import 'package:flutter/foundation.dart';

import '../../../core/ai/ai_models.dart';
import '../../../core/ai/ai_service.dart';
import '../../../core/ai/ai_use_case.dart';
import '../../work_log/repository/work_log_repository.dart';
import '../ai/xiao_mi_ai_prompts.dart';
import '../ai/xiao_mi_prompt_resolver.dart';
import '../models/xiao_mi_conversation.dart';
import '../models/xiao_mi_message.dart';
import '../repository/xiao_mi_repository.dart';

class XiaoMiChatService extends ChangeNotifier {
  static const String assistantThinkingMetadataKey = 'thinking';

  final XiaoMiRepository _repository;
  final AiService _aiService;
  final DateTime Function() _nowProvider;
  final XiaoMiPromptResolver _promptResolver;

  List<XiaoMiConversation> _conversations = const [];
  XiaoMiConversation? _currentConversation;
  List<XiaoMiMessage> _messages = const [];

  bool _sending = false;

  XiaoMiChatService({
    XiaoMiRepository? repository,
    required AiService aiService,
    DateTime Function()? nowProvider,
    XiaoMiPromptResolver? promptResolver,
  }) : _repository = repository ?? XiaoMiRepository(),
       _aiService = aiService,
       _nowProvider = nowProvider ?? DateTime.now,
       _promptResolver =
           promptResolver ??
           XiaoMiPromptResolver(workLogRepository: WorkLogRepository());

  List<XiaoMiConversation> get conversations => _conversations;
  XiaoMiConversation? get currentConversation => _currentConversation;
  List<XiaoMiMessage> get messages => _messages;
  bool get sending => _sending;
  bool get hasStreamingAssistantDraft =>
      _messages.isNotEmpty &&
      _messages.last.role == XiaoMiMessageRole.assistant &&
      _messages.last.id == null;

  List<XiaoMiQuickPrompt> get quickPrompts => _promptResolver.quickPrompts;

  Future<void> init() async {
    await refreshConversations();
    if (_conversations.isEmpty) {
      await newConversation();
      return;
    }
    final first = _conversations.first;
    await openConversation(first.id!);
  }

  Future<void> refreshConversations() async {
    _conversations = await _repository.listConversations();
    notifyListeners();
  }

  Future<void> openConversation(int conversationId) async {
    final convo = await _repository.getConversation(conversationId);
    if (convo == null) return;
    _currentConversation = convo;
    _messages = await _repository.listMessages(conversationId);
    notifyListeners();
  }

  Future<void> newConversation() async {
    final now = _nowProvider();
    final convoId = await _repository.createConversation(
      XiaoMiConversation.create(title: '', now: now),
    );
    await refreshConversations();
    await openConversation(convoId);
  }

  Future<void> renameConversation({
    required int conversationId,
    required String title,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await _repository.updateConversationTitle(
      conversationId: conversationId,
      title: trimmed,
      now: _nowProvider(),
    );
    await refreshConversations();
    if (_currentConversation?.id == conversationId) {
      await openConversation(conversationId);
    }
  }

  Future<void> deleteConversation(int conversationId) async {
    await _repository.deleteConversation(conversationId);
    await refreshConversations();

    if (_currentConversation?.id == conversationId) {
      _currentConversation = null;
      _messages = const [];
      notifyListeners();

      if (_conversations.isEmpty) {
        await newConversation();
      } else {
        await openConversation(_conversations.first.id!);
      }
    }
  }

  Future<void> deleteMessages(Set<int> messageIds) async {
    final activeConversationId = _currentConversation?.id;
    if (activeConversationId == null) return;
    if (messageIds.isEmpty) return;

    final deletedCount = await _repository.deleteMessages(
      conversationId: activeConversationId,
      messageIds: messageIds,
      now: _nowProvider(),
    );
    if (deletedCount <= 0) return;

    _messages = _messages
        .where(
          (message) => message.id == null || !messageIds.contains(message.id),
        )
        .toList(growable: false);
    await refreshConversations();
    notifyListeners();
  }

  Future<void> send(String rawText) async {
    if (_sending) return;
    final convoId = _currentConversation?.id;
    if (convoId == null) {
      await newConversation();
    }
    final activeId = _currentConversation?.id;
    if (activeId == null) return;

    final text = rawText.trim();
    if (text.isEmpty) return;

    _sending = true;
    notifyListeners();
    try {
      final now = _nowProvider();
      final resolved = await _promptResolver.resolveUserInput(text);

      final userMessage = XiaoMiMessage.create(
        conversationId: activeId,
        role: XiaoMiMessageRole.user,
        content: resolved.displayText,
        metadata: resolved.metadata,
        createdAt: now,
      );
      await _repository.addMessage(userMessage);
      _messages = [..._messages, userMessage];
      notifyListeners();

      final historyWithoutCurrentUserMessage = _messages.length <= 1
          ? const <XiaoMiMessage>[]
          : _messages.sublist(0, _messages.length - 1);
      final aiMessages = _buildAiMessages(
        history: historyWithoutCurrentUserMessage,
        currentUserPrompt: resolved.aiPrompt,
      );

      final answerBuffer = StringBuffer();
      final thinkingBuffer = StringBuffer();
      XiaoMiMessage? streamingAssistantMessage;

      await for (final chunk in _aiService.chatStream(
        messages: aiMessages,
        temperature: XiaoMiAiPrompts.chatUseCase.temperature,
        maxOutputTokens: XiaoMiAiPrompts.chatUseCase.maxOutputTokens,
        timeout: XiaoMiAiPrompts.chatUseCase.timeout,
        // 聊天工具本身已存储会话历史；同时避免把“隐式注入数据”写入全局 AI 历史，这里不写入 source。
        source: null,
      )) {
        if (chunk.textDelta.isNotEmpty) {
          answerBuffer.write(chunk.textDelta);
        }
        if (chunk.reasoningDelta.isNotEmpty) {
          thinkingBuffer.write(chunk.reasoningDelta);
        }

        if (chunk.isEmpty) {
          continue;
        }

        final metadata = _buildAssistantMetadata(thinkingBuffer.toString());
        if (streamingAssistantMessage == null) {
          streamingAssistantMessage = XiaoMiMessage.create(
            conversationId: activeId,
            role: XiaoMiMessageRole.assistant,
            content: answerBuffer.toString(),
            metadata: metadata,
            createdAt: _nowProvider(),
          );
          _messages = [..._messages, streamingAssistantMessage];
        } else {
          streamingAssistantMessage = streamingAssistantMessage.copyWith(
            content: answerBuffer.toString(),
            metadata: metadata,
          );
          _messages = [
            ..._messages.sublist(0, _messages.length - 1),
            streamingAssistantMessage,
          ];
        }
        notifyListeners();
      }

      final assistantText = answerBuffer.toString().trim();
      final assistantMetadata = _buildAssistantMetadata(
        thinkingBuffer.toString(),
      );
      final assistantMessage = XiaoMiMessage.create(
        conversationId: activeId,
        role: XiaoMiMessageRole.assistant,
        content: assistantText,
        metadata: assistantMetadata,
        createdAt: streamingAssistantMessage?.createdAt ?? _nowProvider(),
      );
      await _repository.addMessage(assistantMessage);
      if (streamingAssistantMessage == null) {
        _messages = [..._messages, assistantMessage];
      } else {
        _messages = [
          ..._messages.sublist(0, _messages.length - 1),
          assistantMessage,
        ];
      }
      await _autoTitleIfNeeded(activeId);
      await refreshConversations();
      notifyListeners();
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> _autoTitleIfNeeded(int conversationId) async {
    final convo = _currentConversation;
    if (convo == null || convo.id != conversationId) return;
    if (convo.title.trim().isNotEmpty) return;
    final firstUser = _messages.firstWhere(
      (m) => m.role == XiaoMiMessageRole.user && m.content.trim().isNotEmpty,
      orElse: () => XiaoMiMessage(
        id: null,
        conversationId: -1,
        role: XiaoMiMessageRole.user,
        content: '',
        metadata: null,
        createdAt: DateTime(1970, 1, 1),
      ),
    );
    final seed = firstUser.content.trim();
    if (seed.isEmpty) return;
    final title = seed.length <= 16 ? seed : '${seed.substring(0, 16)}…';
    await _repository.updateConversationTitle(
      conversationId: conversationId,
      title: title,
      now: _nowProvider(),
    );
    _currentConversation = (await _repository.getConversation(conversationId));
  }

  List<AiMessage> _buildAiMessages({
    required List<XiaoMiMessage> history,
    required String currentUserPrompt,
  }) {
    const maxHistoryMessages = 20;
    final effectiveHistory = history
        .where(
          (m) =>
              m.role == XiaoMiMessageRole.user ||
              m.role == XiaoMiMessageRole.assistant,
        )
        .toList(growable: false);

    final trimmedHistory = effectiveHistory.length <= maxHistoryMessages
        ? effectiveHistory
        : effectiveHistory.sublist(
            effectiveHistory.length - maxHistoryMessages,
          );

    final aiHistory = trimmedHistory
        .map(
          (m) => switch (m.role) {
            XiaoMiMessageRole.user => AiMessage.user(m.content),
            XiaoMiMessageRole.assistant => AiMessage.assistant(m.content),
            _ => AiMessage.user(m.content),
          },
        )
        .toList(growable: false);

    return <AiMessage>[
      AiMessage.system(XiaoMiAiPrompts.chatUseCase.systemPrompt),
      ...aiHistory,
      AiMessage.user(
        AiPromptComposer.compose(
          inputLabel: XiaoMiAiPrompts.chatUseCase.inputLabel,
          userInput: currentUserPrompt,
        ),
      ),
    ];
  }

  Map<String, dynamic>? _buildAssistantMetadata(String thinking) {
    final trimmedThinking = thinking.trim();
    if (trimmedThinking.isEmpty) {
      return null;
    }
    return <String, dynamic>{assistantThinkingMetadataKey: trimmedThinking};
  }
}
