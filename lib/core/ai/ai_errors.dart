class AiNotConfiguredException implements Exception {
  final String message;
  const AiNotConfiguredException([this.message = 'AI 未配置']);

  @override
  String toString() => 'AiNotConfiguredException: $message';
}

class AiApiException implements Exception {
  final int statusCode;
  final String message;
  final String? responseBody;

  const AiApiException({
    required this.statusCode,
    required this.message,
    this.responseBody,
  });

  @override
  String toString() => 'AiApiException($statusCode): $message';
}

