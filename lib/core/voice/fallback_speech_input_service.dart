import 'package:flutter/services.dart';

import 'speech_input_service.dart';

class FallbackSpeechInputService implements SpeechInputService {
  final SpeechInputService primary;
  final SpeechInputService fallback;

  const FallbackSpeechInputService({
    required this.primary,
    required this.fallback,
  });

  @override
  Future<String?> listenOnce({
    Duration timeout = const Duration(seconds: 20),
    void Function(String partialText)? onPartial,
  }) async {
    try {
      final text = await primary.listenOnce(
        timeout: timeout,
        onPartial: onPartial,
      );
      if (text != null && text.trim().isNotEmpty) return text.trim();
    } on SpeechInputNotSupportedException {
      // fallback
    } on PlatformException catch (e) {
      if (!_shouldFallbackForPlatformException(e)) rethrow;
    }

    final text = await fallback.listenOnce(
      timeout: timeout,
      onPartial: onPartial,
    );
    return text?.trim().isEmpty == true ? null : text?.trim();
  }

  static bool _shouldFallbackForPlatformException(PlatformException e) {
    final code = e.code;
    return code == 'recognizerNotAvailable' ||
        code == 'speech_recognition_not_available';
  }
}
