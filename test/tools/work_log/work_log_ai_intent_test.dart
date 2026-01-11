import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/tools/work_log/ai/work_log_ai_intent.dart';
import 'package:life_tools/tools/work_log/models/work_task.dart';

void main() {
  group('WorkLogAiIntentParser', () {
    test('应该解析 create_task 意图并生成任务草稿', () {
      const jsonText = '''
{
  "type": "create_task",
  "task": {
    "title": "实现语音输入",
    "description": "在任务页底部加语音按钮",
    "status": "doing",
    "estimated_minutes": 120,
    "start_at": "2026-01-11T09:00:00",
    "end_at": null
  }
}
''';

      final intent = WorkLogAiIntentParser.parse(jsonText);

      expect(intent, isA<CreateTaskIntent>());
      final create = intent as CreateTaskIntent;
      expect(create.draft.title, '实现语音输入');
      expect(create.draft.description, '在任务页底部加语音按钮');
      expect(create.draft.status, WorkTaskStatus.doing);
      expect(create.draft.estimatedMinutes, 120);
      expect(create.draft.startAt, DateTime(2026, 1, 11, 9));
      expect(create.draft.endAt, isNull);
    });

    test('应该解析 add_time_entry 意图并生成工时草稿', () {
      const jsonText = '''
{
  "type": "add_time_entry",
  "task_ref": { "title": "任务A" },
  "time_entry": {
    "work_date": "2026-01-02",
    "minutes": 90,
    "content": "开发功能A"
  }
}
''';

      final intent = WorkLogAiIntentParser.parse(jsonText);

      expect(intent, isA<AddTimeEntryIntent>());
      final add = intent as AddTimeEntryIntent;
      expect(add.taskRef.title, '任务A');
      expect(add.draft.workDate, DateTime(2026, 1, 2));
      expect(add.draft.minutes, 90);
      expect(add.draft.content, '开发功能A');
    });

    test('状态字段应该兼容中文', () {
      const jsonText = '''
{
  "type": "create_task",
  "task": {
    "title": "任务A",
    "status": "进行中"
  }
}
''';

      final intent = WorkLogAiIntentParser.parse(jsonText) as CreateTaskIntent;
      expect(intent.draft.status, WorkTaskStatus.doing);
    });

    test('应该允许从包含多余文本的内容中提取 JSON', () {
      const jsonText = '''
下面是结果（仅 JSON）：
{"type":"create_task","task":{"title":"任务A","status":"todo"}}
''';

      final intent = WorkLogAiIntentParser.parse(jsonText) as CreateTaskIntent;
      expect(intent.draft.title, '任务A');
      expect(intent.draft.status, WorkTaskStatus.todo);
    });
  });
}

