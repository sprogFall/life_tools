import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_photo/services/work_photo_item_selection.dart';

void main() {
  group('resolveSelectedItemIdAfterCapture', () {
    test('当前项已达标时仍保持当前拍摄项，不自动跳转', () {
      final selected = resolveSelectedItemIdAfterCapture(currentItemId: 11);

      expect(selected, 11);
    });

    test('无论是否还有其他未完成拍摄项，都保持当前项', () {
      final selected = resolveSelectedItemIdAfterCapture(currentItemId: 22);

      expect(selected, 22);
    });
  });
}
