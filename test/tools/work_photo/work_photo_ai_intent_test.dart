import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_photo/ai/work_photo_ai_intent.dart';

void main() {
  group('WorkPhotoAiIntentParser', () {
    test('replace_template_tree: 能解析层级与拍摄项树', () {
      const json = '''
{
  "type": "replace_template_tree",
  "nodes": [
    {
      "kind": "level",
      "name": "区域",
      "is_required": true,
      "children": [
        {
          "kind": "level",
          "name": "门店",
          "children": [
            {
              "kind": "item",
              "name": "门头",
              "min_count": 1,
              "max_count": 3
            },
            {
              "kind": "item",
              "name": "桌面",
              "min_count": 2
            }
          ]
        }
      ]
    },
    {
      "kind": "item",
      "name": "签到照",
      "min_count": 1,
      "max_count": null
    }
  ]
}
''';

      final intent = WorkPhotoAiIntentParser.parse(json);
      expect(intent, isA<WorkPhotoAiReplaceTemplateTreeIntent>());
      final tree = intent as WorkPhotoAiReplaceTemplateTreeIntent;
      expect(tree.nodes, hasLength(2));

      final area = tree.nodes.first;
      expect(area.isLevel, isTrue);
      expect(area.name, '区域');
      expect(area.isRequired, isTrue);
      expect(area.children, hasLength(1));

      final store = area.children.single;
      expect(store.name, '门店');
      expect(store.children, hasLength(2));
      expect(store.children[0].name, '门头');
      expect(store.children[0].minCount, 1);
      expect(store.children[0].maxCount, 3);
      expect(store.children[1].name, '桌面');
      expect(store.children[1].minCount, 2);
      expect(store.children[1].maxCount, isNull);

      final signIn = tree.nodes[1];
      expect(signIn.isItem, isTrue);
      expect(signIn.name, '签到照');
      expect(signIn.maxCount, isNull);
    });

    test('带噪声 JSON 也能解析', () {
      const json = '''
好的，配置如下：
```json
{"type":"replace_template_tree","nodes":[{"kind":"item","name":"门头","min_count":1}]}
```
''';
      final intent = WorkPhotoAiIntentParser.parse(json);
      expect(intent, isA<WorkPhotoAiReplaceTemplateTreeIntent>());
      final tree = intent as WorkPhotoAiReplaceTemplateTreeIntent;
      expect(tree.nodes.single.name, '门头');
    });

    test('未知 type 返回 UnknownIntent', () {
      final intent = WorkPhotoAiIntentParser.parse('{"type":"nope"}');
      expect(intent, isA<WorkPhotoAiUnknownIntent>());
      expect((intent as WorkPhotoAiUnknownIntent).reason, contains('type'));
    });

    test('nodes 为空返回 UnknownIntent', () {
      final intent = WorkPhotoAiIntentParser.parse(
        '{"type":"replace_template_tree","nodes":[]}',
      );
      expect(intent, isA<WorkPhotoAiUnknownIntent>());
    });

    test('item 的 max_count 小于 min_count 返回 UnknownIntent', () {
      final intent = WorkPhotoAiIntentParser.parse('''
{
  "type": "replace_template_tree",
  "nodes": [
    {"kind":"item","name":"门头","min_count":3,"max_count":1}
  ]
}
''');
      expect(intent, isA<WorkPhotoAiUnknownIntent>());
      expect(
        (intent as WorkPhotoAiUnknownIntent).reason,
        contains('max_count'),
      );
    });

    test('item 带 children 返回 UnknownIntent', () {
      final intent = WorkPhotoAiIntentParser.parse('''
{
  "type": "replace_template_tree",
  "nodes": [
    {
      "kind": "item",
      "name": "门头",
      "children": [{"kind":"item","name":"子项"}]
    }
  ]
}
''');
      expect(intent, isA<WorkPhotoAiUnknownIntent>());
      expect((intent as WorkPhotoAiUnknownIntent).reason, contains('children'));
    });
  });
}
