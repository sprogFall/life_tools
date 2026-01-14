import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../ai/ai_service.dart';
import 'speech_input_service.dart';

class AiAudioTranscriptionInputService implements SpeechInputService {
  final AiService _aiService;
  final AudioRecorder _recorder;

  AiAudioTranscriptionInputService({
    required AiService aiService,
    AudioRecorder? recorder,
  }) : _aiService = aiService,
       _recorder = recorder ?? AudioRecorder();

  @override
  Future<String?> listenOnce({
    Duration timeout = const Duration(seconds: 20),
    void Function(String partialText)? onPartial,
  }) async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return null;

    final dir = await getTemporaryDirectory();
    final filePath = p.join(
      dir.path,
      'life_tools_voice_${DateTime.now().millisecondsSinceEpoch}.wav',
    );

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: filePath,
      );

      await _waitForSpeechEnd(timeout: timeout);

      final recordedPath = await _recorder.stop();
      if (recordedPath == null) return null;

      String text;
      try {
        text = await _aiService.transcribeAudioFile(filePath: recordedPath);
      } on UnimplementedError {
        return null;
      }
      final cleaned = text.trim();
      return cleaned.isEmpty ? null : cleaned;
    } finally {
      try {
        if (await _recorder.isRecording()) {
          await _recorder.stop();
        }
      } catch (_) {
        // ignore
      }

      try {
        final f = File(filePath);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // ignore
      }
    }
  }

  Future<void> _waitForSpeechEnd({required Duration timeout}) async {
    final done = Completer<void>();
    Timer? silenceTimer;
    StreamSubscription<Amplitude>? sub;
    var heardNonSilence = false;

    void finish() {
      if (done.isCompleted) return;
      done.complete();
    }

    final hardTimeout = Timer(timeout, finish);

    try {
      sub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 200))
          .listen((amp) {
            // `record` 的振幅单位为 dB，越接近 0 越大声，负数越小声。
            final current = amp.current;

            // 简单阈值：>-35 认为有声音；连续静默 > 1.2s 认为结束。
            if (current > -35) {
              heardNonSilence = true;
              silenceTimer?.cancel();
              silenceTimer = null;
            } else if (heardNonSilence) {
              silenceTimer ??= Timer(
                const Duration(milliseconds: 1200),
                finish,
              );
            }
          });
    } catch (_) {
      // 某些平台/实现可能不支持振幅回调，退化为仅硬超时。
    }

    try {
      await done.future;
    } finally {
      hardTimeout.cancel();
      silenceTimer?.cancel();
      final subscription = sub;
      if (subscription != null) {
        await subscription.cancel();
      }
    }
  }
}
