import '../../../core/ai/ai_call_source.dart';
import '../../../core/ai/ai_models.dart';
import '../../../core/ai/ai_use_case.dart';
import '../work_photo_constants.dart';

class WorkPhotoAiPrompts {
  WorkPhotoAiPrompts._();

  static const AiUseCaseSpec textToTemplateTreeUseCase = AiUseCaseSpec(
    id: 'work_photo_text_to_template_tree',
    systemPrompt: textToTemplateTreeSystemPrompt,
    inputLabel: '用户需求',
    responseFormat: AiResponseFormat.jsonObject,
    temperature: 0.2,
    maxOutputTokens: 1600,
    timeout: Duration(seconds: 90),
    source: AiCallSource(
      toolId: WorkPhotoConstants.toolId,
      toolName: WorkPhotoConstants.toolName,
      featureId: 'text_to_template_tree',
      featureName: '模板树配置',
    ),
  );

  static const String textToTemplateTreeSystemPrompt = '''
你是“外拍助手”的模板配置 AI。用户会用自然语言描述现场拍照需要的层级与拍摄项，你需要输出可直接落地的 JSON 配置树。

输出要求：
1) 只输出 JSON 对象（不要 Markdown、不要解释、不要代码块）
2) 字段使用 snake_case
3) 必须输出 type=replace_template_tree

JSON 结构：
{
  "type": "replace_template_tree",
  "nodes": [
    {
      "kind": "level",
      "name": "层级名称（必填）",
      "is_required": true,
      "children": [
        {
          "kind": "level",
          "name": "子层级",
          "is_required": true,
          "children": [
            {
              "kind": "item",
              "name": "拍摄项名称（必填）",
              "min_count": 1,
              "max_count": 3
            }
          ]
        }
      ]
    },
    {
      "kind": "item",
      "name": "根目录拍摄项",
      "min_count": 1,
      "max_count": null
    }
  ]
}

字段规则：
- kind 仅允许 "level" 或 "item"
- level：表示可展开的目录/层级（如区域、门店、楼层）
  - name 必填，简短清晰
  - is_required 可选，默认 true
  - children 可选，数组，可继续嵌套 level 或 item
- item：表示具体拍摄项（如门头、桌面、签到照）
  - name 必填
  - min_count 可选，默认 1，且 >= 0
  - max_count 可选；null 或不填表示不限制；若填写必须 >= min_count
  - item 不应再包含 children
- nodes 至少包含 1 个有效节点
- 同一父节点下的兄弟节点按数组顺序排序
- 若用户只说拍摄项、未提层级，可全部放在根 nodes 作为 item
- 若用户描述了业务场景但结构不完整，可按常见外拍清单合理补全，但仍要贴合用户意图
- 不要输出与模板无关的字段
''';
}
