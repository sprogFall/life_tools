import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/xiao_mi/ai/xiao_mi_ai_prompts.dart';

void main() {
  test('preRouteSystemPrompt 应声明任务查询与工时查询协议', () {
    expect(XiaoMiAiPrompts.preRouteSystemPrompt, contains('work_task_query'));
    expect(XiaoMiAiPrompts.preRouteSystemPrompt, contains('work_time_query'));
    expect(XiaoMiAiPrompts.preRouteSystemPrompt, contains('work_log_query'));
    expect(XiaoMiAiPrompts.preRouteSystemPrompt, contains('affiliation_names'));
    expect(XiaoMiAiPrompts.preRouteSystemPrompt, contains('statuses'));
    expect(XiaoMiAiPrompts.preRouteSystemPrompt, contains('fields'));
  });
}
