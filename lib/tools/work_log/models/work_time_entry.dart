class WorkTimeEntry {
  final int? id;
  final int taskId;
  final DateTime workDate;
  final int minutes;
  final String content;
  final DateTime createdAt;

  const WorkTimeEntry({
    required this.id,
    required this.taskId,
    required this.workDate,
    required this.minutes,
    required this.content,
    required this.createdAt,
  });

  factory WorkTimeEntry.create({
    required int taskId,
    required DateTime workDate,
    required int minutes,
    required String content,
    DateTime? now,
  }) {
    return WorkTimeEntry(
      id: null,
      taskId: taskId,
      workDate: _startOfDay(workDate),
      minutes: minutes,
      content: content,
      createdAt: now ?? DateTime.now(),
    );
  }

  WorkTimeEntry copyWith({
    int? id,
    int? taskId,
    DateTime? workDate,
    int? minutes,
    String? content,
    DateTime? createdAt,
  }) {
    return WorkTimeEntry(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      workDate: workDate != null ? _startOfDay(workDate) : this.workDate,
      minutes: minutes ?? this.minutes,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId) 'id': id,
      'task_id': taskId,
      'work_date': _startOfDay(workDate).millisecondsSinceEpoch,
      'minutes': minutes,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory WorkTimeEntry.fromMap(Map<String, Object?> map) {
    return WorkTimeEntry(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      workDate: DateTime.fromMillisecondsSinceEpoch(map['work_date'] as int),
      minutes: map['minutes'] as int,
      content: (map['content'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  static DateTime _startOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }
}

