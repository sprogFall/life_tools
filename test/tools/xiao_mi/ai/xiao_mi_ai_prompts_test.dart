import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_ai_prompts.dart';

void main() {
  test('preRouteSystemPrompt 应声明 work_log_query 的筛选与字段协议', () {
    expect(XiaoMiAiPrompts.preRouteSystemPrompt, contains('work_log_query'));
    expect(XiaoMiAiPrompts.preRouteSystemPrompt, contains('affiliation_names'));
    expect(XiaoMiAiPrompts.preRouteSystemPrompt, contains('statuses'));
    expect(XiaoMiAiPrompts.preRouteSystemPrompt, contains('fields'));
  });
}
