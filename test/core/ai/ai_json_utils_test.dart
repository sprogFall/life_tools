import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/ai/ai_json_utils.dart';

void main() {
  group('AiJsonUtils', () {
    test('decodeFirstObject 应支持带前后缀文本的 JSON', () {
      const text = '输出如下：\n{"type":"create_task","task":{"title":"任务A"}}\n谢谢';

      final map = AiJsonUtils.decodeFirstObject(text);

      expect(map, isNotNull);
      expect(map!['type'], 'create_task');
    });

    test('decodeFirstObject 在无合法 JSON 时返回 null', () {
      final map = AiJsonUtils.decodeFirstObject('not-json');
      expect(map, isNull);
    });

    test('asInt / asDouble 应兼容数字和字符串', () {
      expect(AiJsonUtils.asInt(3.6), 4);
      expect(AiJsonUtils.asInt('12'), 12);
      expect(AiJsonUtils.asDouble('1.5'), 1.5);
      expect(AiJsonUtils.asDouble(2), 2.0);
    });

    test('parseDateOnly 应归一化为零点日期', () {
      final date = AiJsonUtils.parseDateOnly('2026-02-07T12:30:00');

      expect(date, DateTime(2026, 2, 7));
    });
  });
}
