import 'dart:convert';

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
    final map = _decodeJsonObject(text);
    if (map == null) {
      return const UnknownIntent(reason: '无法解析 JSON');
    }

    final type = _asString(map['type'])?.trim();
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
    final task = _asMap(root['task']);
    if (task == null) {
      return UnknownIntent(reason: 'create_task 缺少 task 对象', raw: root);
    }

    final title = _asString(task['title'])?.trim();
    if (title == null || title.isEmpty) {
      return UnknownIntent(reason: 'create_task 缺少 task.title', raw: root);
    }

    return CreateTaskIntent(
      draft: WorkTaskDraft(
        title: title,
        description: _asString(task['description'])?.trim() ?? '',
        status: _parseStatus(_asString(task['status'])) ?? WorkTaskStatus.todo,
        estimatedMinutes: _asInt(task['estimated_minutes']) ?? 0,
        startAt: _parseDateTime(_asString(task['start_at'])),
        endAt: _parseDateTime(_asString(task['end_at'])),
      ),
    );
  }

  static WorkLogAiIntent _parseAddTimeEntry(Map<String, Object?> root) {
    final taskRefMap = _asMap(root['task_ref']);
    final taskRef = WorkLogTaskRef(
      id: taskRefMap != null ? _asInt(taskRefMap['id']) : null,
      title: taskRefMap != null ? _asString(taskRefMap['title'])?.trim() : null,
    );

    final timeEntry = _asMap(root['time_entry']);
    if (timeEntry == null) {
      return UnknownIntent(
        reason: 'add_time_entry 缺少 time_entry 对象',
        raw: root,
      );
    }

    final minutes = _asInt(timeEntry['minutes']);
    if (minutes == null || minutes <= 0) {
      return UnknownIntent(reason: 'add_time_entry 缺少有效的 minutes', raw: root);
    }

    final workDateString = _asString(timeEntry['work_date']);
    final workDate = _parseDateOnly(workDateString) ?? DateTime.now();

    return AddTimeEntryIntent(
      taskRef: taskRef,
      draft: WorkTimeEntryDraft(
        workDate: workDate,
        minutes: minutes,
        content: _asString(timeEntry['content'])?.trim() ?? '',
      ),
    );
  }

  static Map<String, Object?>? _decodeJsonObject(String text) {
    final trimmed = text.trim();
    final decoded = _tryDecodeObject(trimmed);
    if (decoded != null) return decoded;

    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final extracted = trimmed.substring(start, end + 1);
    return _tryDecodeObject(extracted);
  }

  static Map<String, Object?>? _tryDecodeObject(String text) {
    try {
      final value = jsonDecode(text);
      if (value is Map) {
        return value.cast<String, Object?>();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, Object?>? _asMap(Object? value) {
    if (value is Map) return value.cast<String, Object?>();
    return null;
  }

  static String? _asString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    return value.toString();
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  static DateTime? _parseDateTime(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim());
  }

  static DateTime? _parseDateOnly(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
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
