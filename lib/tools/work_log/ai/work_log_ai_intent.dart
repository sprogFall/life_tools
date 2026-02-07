import '../../../core/ai/ai_json_utils.dart';
import '../models/work_log_drafts.dart';
import '../models/work_task.dart';

sealed class WorkLogAiIntent {
  const WorkLogAiIntent();
}

class UnknownIntent extends WorkLogAiIntent {
  final String reason;
  final Map<String, Object?>? raw;

  const UnknownIntent({required this.reason, this.raw});
}

class CreateTaskIntent extends WorkLogAiIntent {
  final WorkTaskDraft draft;

  const CreateTaskIntent({required this.draft});
}

class AddTimeEntryIntent extends WorkLogAiIntent {
  final WorkLogTaskRef taskRef;
  final WorkTimeEntryDraft draft;

  const AddTimeEntryIntent({required this.taskRef, required this.draft});
}

class WorkLogAiIntentParser {
  static WorkLogAiIntent parse(String text) {
    final map = AiJsonUtils.decodeFirstObject(text);
    if (map == null) {
      return const UnknownIntent(reason: '无法解析 JSON');
    }

    final type = AiJsonUtils.asString(map['type'])?.trim();
    if (type == null || type.isEmpty) {
      return UnknownIntent(reason: '缺少 type 字段', raw: map);
    }

    switch (type) {
      case 'create_task':
        return _parseCreateTask(map);
      case 'add_time_entry':
        return _parseAddTimeEntry(map);
      default:
        return UnknownIntent(reason: '不支持的 type: $type', raw: map);
    }
  }

  static WorkLogAiIntent _parseCreateTask(Map<String, Object?> root) {
    final task = AiJsonUtils.asMap(root['task']);
    if (task == null) {
      return UnknownIntent(reason: 'create_task 缺少 task 对象', raw: root);
    }

    final title = AiJsonUtils.asString(task['title'])?.trim();
    if (title == null || title.isEmpty) {
      return UnknownIntent(reason: 'create_task 缺少 task.title', raw: root);
    }

    return CreateTaskIntent(
      draft: WorkTaskDraft(
        title: title,
        description: AiJsonUtils.asString(task['description'])?.trim() ?? '',
        status:
            _parseStatus(AiJsonUtils.asString(task['status'])) ??
            WorkTaskStatus.todo,
        estimatedMinutes: AiJsonUtils.asInt(task['estimated_minutes']) ?? 0,
        startAt: AiJsonUtils.parseDateTime(
          AiJsonUtils.asString(task['start_at']),
        ),
        endAt: AiJsonUtils.parseDateTime(AiJsonUtils.asString(task['end_at'])),
      ),
    );
  }

  static WorkLogAiIntent _parseAddTimeEntry(Map<String, Object?> root) {
    final taskRefMap = AiJsonUtils.asMap(root['task_ref']);
    final taskRef = WorkLogTaskRef(
      id: taskRefMap != null ? AiJsonUtils.asInt(taskRefMap['id']) : null,
      title: taskRefMap != null
          ? AiJsonUtils.asString(taskRefMap['title'])?.trim()
          : null,
    );

    final timeEntry = AiJsonUtils.asMap(root['time_entry']);
    if (timeEntry == null) {
      return UnknownIntent(
        reason: 'add_time_entry 缺少 time_entry 对象',
        raw: root,
      );
    }

    final minutes = AiJsonUtils.asInt(timeEntry['minutes']);
    if (minutes == null || minutes <= 0) {
      return UnknownIntent(reason: 'add_time_entry 缺少有效的 minutes', raw: root);
    }

    final workDate =
        AiJsonUtils.parseDateOnly(
          AiJsonUtils.asString(timeEntry['work_date']),
        ) ??
        DateTime.now();

    return AddTimeEntryIntent(
      taskRef: taskRef,
      draft: WorkTimeEntryDraft(
        workDate: workDate,
        minutes: minutes,
        content: AiJsonUtils.asString(timeEntry['content'])?.trim() ?? '',
      ),
    );
  }

  static WorkTaskStatus? _parseStatus(String? value) {
    if (value == null) return null;
    final s = value.trim().toLowerCase();
    return switch (s) {
      'todo' || '待办' || '待辦' => WorkTaskStatus.todo,
      'doing' || '进行中' || '进行' => WorkTaskStatus.doing,
      'done' || '已完成' || '完成' => WorkTaskStatus.done,
      'canceled' || 'cancelled' || '已取消' || '取消' => WorkTaskStatus.canceled,
      _ => null,
    };
  }
}
