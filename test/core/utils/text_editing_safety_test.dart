import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/utils/text_editing_safety.dart';

void main() {
  group('TextEditingSafety', () {
    test('应识别激活的 composing 区间', () {
      final value = const TextEditingValue(
        text: 'nihao',
        composing: TextRange(start: 0, end: 5),
      );

      expect(hasActiveImeComposing(value), isTrue);
    });

    test('composing 为空时应判定为未激活', () {
      final value = const TextEditingValue(
        text: '你好',
        composing: TextRange.empty,
      );

      expect(hasActiveImeComposing(value), isFalse);
    });

    test('无 composing 时应写入新文本并保留可用光标位置', () {
      final controller = TextEditingController(text: 'abcd')
        ..selection = const TextSelection.collapsed(offset: 2);

      final ok = setControllerTextIfNoActiveComposing(controller, 'xy');

      expect(ok, isTrue);
      expect(controller.text, 'xy');
      expect(controller.selection.baseOffset, 2);
      expect(controller.selection.extentOffset, 2);
      controller.dispose();
    });

    test('有 composing 时不应覆盖文本', () {
      final controller = TextEditingController(text: 'ni')
        ..value = const TextEditingValue(
          text: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        );

      final ok = setControllerTextIfNoActiveComposing(controller, '你');

      expect(ok, isFalse);
      expect(controller.text, 'ni');
      controller.dispose();
    });

    testWidgets('composing 结束后应可通过重试写入文本', (tester) async {
      final controller = TextEditingController(text: 'ni')
        ..value = const TextEditingValue(
          text: 'ni',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 0, end: 2),
        );

      setControllerTextWhenComposingIdle(
        controller,
        '你',
        maxRetries: 3,
        retryDelay: const Duration(milliseconds: 10),
      );

      await tester.pump(const Duration(milliseconds: 10));
      expect(controller.text, 'ni');

      controller.value = controller.value.copyWith(composing: TextRange.empty);

      await tester.pump(const Duration(milliseconds: 10));
      expect(controller.text, '你');
      controller.dispose();
    });
  });
}
