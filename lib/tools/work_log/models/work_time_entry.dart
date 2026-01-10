class WorkTimeEntry {
  final int? id;
  final int taskId;
  final DateTime workDate;
  final int minutes;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkTimeEntry({
    required this.id,
    required this.taskId,
    required this.workDate,
    required this.minutes,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkTimeEntry.create({
    required int taskId,
    required DateTime workDate,
    required int minutes,
    required String content,
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    return WorkTimeEntry(
      id: null,
      taskId: taskId,
      workDate: _startOfDay(workDate),
      minutes: minutes,
      content: content,
      createdAt: time,
      updatedAt: time,
    );
  }

  WorkTimeEntry copyWith({
    int? id,
    int? taskId,
    DateTime? workDate,
    int? minutes,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkTimeEntry(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      workDate: workDate != null ? _startOfDay(workDate) : this.workDate,
      minutes: minutes ?? this.minutes,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory WorkTimeEntry.fromMap(Map<String, Object?> map) {
    final createdAt = DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int);
    final updatedAtValue = map['updated_at'] as int?;
    return WorkTimeEntry(
      id: map['id'] as int?,
      taskId: map['task_id'] as int,
      workDate: DateTime.fromMillisecondsSinceEpoch(map['work_date'] as int),
      minutes: map['minutes'] as int,
      content: (map['content'] as String?) ?? '',
      createdAt: createdAt,
      updatedAt: updatedAtValue != null
          ? DateTime.fromMillisecondsSinceEpoch(updatedAtValue)
          : createdAt,
    );
  }

  static DateTime _startOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }
}

