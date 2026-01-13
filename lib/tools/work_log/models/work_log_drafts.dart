import 'work_task.dart';

class WorkLogTaskRef {
  final int? id;
  final String? title;

  const WorkLogTaskRef({this.id, this.title});
}

class WorkTaskDraft {
  final String title;
  final String description;
  final DateTime? startAt;
  final DateTime? endAt;
  final WorkTaskStatus status;
  final int estimatedMinutes;

  const WorkTaskDraft({
    required this.title,
    this.description = '',
    this.startAt,
    this.endAt,
    this.status = WorkTaskStatus.todo,
    this.estimatedMinutes = 0,
  });
}

class WorkTimeEntryDraft {
  final DateTime workDate;
  final int minutes;
  final String content;

  const WorkTimeEntryDraft({
    required this.workDate,
    required this.minutes,
    this.content = '',
  });
}
