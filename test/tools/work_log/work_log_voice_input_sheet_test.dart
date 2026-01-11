import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/voice/speech_input_service.dart';
import 'package:life_tools/tools/work_log/pages/task/work_log_voice_input_sheet.dart';

void main() {
  group('WorkLogVoiceInputSheet', () {
    testWidgets('不支持语音识别时应提示用户手动输入', (tester) async {
      final service = _NotSupportedSpeechInputService();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    WorkLogVoiceInputSheet.show(
                      context,
                      speechInputService: service,
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle(const Duration(milliseconds: 800));

      await tester.tap(find.text('开始说话'));
      await tester.pump();
      await tester.pumpAndSettle(const Duration(milliseconds: 800));

      expect(find.text('当前平台暂不支持语音识别'), findsOneWidget);
    });
  });
}

class _NotSupportedSpeechInputService implements SpeechInputService {
  @override
  Future<String?> listenOnce({
    Duration timeout = const Duration(seconds: 20),
    void Function(String partialText)? onPartial,
  }) async {
    throw const SpeechInputNotSupportedException();
  }
}

