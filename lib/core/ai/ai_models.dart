enum AiRole { system, user, assistant }

class AiMessage {
  final AiRole role;
  final String content;

  const AiMessage({required this.role, required this.content});

  const AiMessage.system(String content)
    : this(role: AiRole.system, content: content);

  const AiMessage.user(String content)
    : this(role: AiRole.user, content: content);

  const AiMessage.assistant(String content)
    : this(role: AiRole.assistant, content: content);

  Map<String, dynamic> toJson() => {'role': role.name, 'content': content};
}

enum AiResponseFormat { text, jsonObject }

class AiTokenUsage {
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  const AiTokenUsage({
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  bool get isEmpty =>
      promptTokens == null && completionTokens == null && totalTokens == null;
}

class AiChatRequest {
  final List<AiMessage> messages;
  final double? temperature;
  final int? maxOutputTokens;
  final AiResponseFormat responseFormat;

  const AiChatRequest({
    required this.messages,
    this.temperature,
    this.maxOutputTokens,
    this.responseFormat = AiResponseFormat.text,
  });
}

class AiChatResult {
  final String text;
  final String reasoning;
  final AiTokenUsage? usage;

  const AiChatResult({required this.text, this.reasoning = '', this.usage});
}

class AiChatStreamChunk {
  final String textDelta;
  final String reasoningDelta;
  final AiTokenUsage? usage;

  const AiChatStreamChunk({
    this.textDelta = '',
    this.reasoningDelta = '',
    this.usage,
  });

  bool get isEmpty =>
      textDelta.isEmpty && reasoningDelta.isEmpty && usage == null;
}
