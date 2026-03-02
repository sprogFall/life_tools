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

  const AiChatResult({required this.text, this.reasoning = ''});
}

class AiChatStreamChunk {
  final String textDelta;
  final String reasoningDelta;

  const AiChatStreamChunk({this.textDelta = '', this.reasoningDelta = ''});

  bool get isEmpty => textDelta.isEmpty && reasoningDelta.isEmpty;
}
