import 'dart:async';

import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

abstract interface class SpeechInputService {
  Future<String?> listenOnce({
    Duration timeout = const Duration(seconds: 20),
    void Function(String partialText)? onPartial,
  });
}

class SpeechInputNotSupportedException implements Exception {
  final String message;
  const SpeechInputNotSupportedException([this.message = '当前平台暂不支持语音识别']);

  @override
  String toString() => message;
}

class SpeechToTextInputService implements SpeechInputService {
  final stt.SpeechToText _speech;

  SpeechToTextInputService({stt.SpeechToText? speech}) : _speech = speech ?? stt.SpeechToText();

  @override
  Future<String?> listenOnce({
    Duration timeout = const Duration(seconds: 20),
    void Function(String partialText)? onPartial,
  }) async {
    final bool supported;
    try {
      supported = await _speech.initialize();
    } on MissingPluginException {
      throw const SpeechInputNotSupportedException();
    }
    if (!supported) return null;

    final completer = Completer<String?>();
    var lastText = '';

    void finish([String? value]) {
      if (completer.isCompleted) return;
      completer.complete(value);
    }

    Timer? timer;
    try {
      timer = Timer(timeout, () async {
        try {
          await _speech.stop();
        } finally {
          finish(lastText.trim().isEmpty ? null : lastText.trim());
        }
      });

      await _speech.listen(
        onResult: (SpeechRecognitionResult result) {
          final text = result.recognizedWords;
          lastText = text;
          onPartial?.call(text);
          if (result.finalResult) {
            finish(text.trim().isEmpty ? null : text.trim());
          }
        },
      );

      final value = await completer.future;
      await _speech.stop();
      return value;
    } finally {
      timer?.cancel();
    }
  }
}
