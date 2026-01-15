import '../../../core/tag/models/tag_model.dart';

enum WorkTaskStatus {
  todo(0),
  doing(1),
  done(2),
  canceled(3);

  final int value;
  const WorkTaskStatus(this.value);

  static WorkTaskStatus fromValue(int value) {
    return WorkTaskStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => WorkTaskStatus.todo,
    );
  }
}

class WorkTask {
  final int? id;
  final String title;
  final String description;
  final DateTime? startAt;
  final DateTime? endAt;
  final WorkTaskStatus status;
  final int estimatedMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Tag> tags;

  const WorkTask({
    required this.id,
    required this.title,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.estimatedMinutes,
    required this.createdAt,
    required this.updatedAt,
    required this.tags,
  });

  factory WorkTask.create({
    required String title,
    required String description,
    required DateTime? startAt,
    required DateTime? endAt,
    required WorkTaskStatus status,
    required int estimatedMinutes,
    List<Tag> tags = const [],
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    return WorkTask(
      id: null,
      title: title,
      description: description,
      startAt: startAt,
      endAt: endAt,
      status: status,
      estimatedMinutes: estimatedMinutes,
      createdAt: time,
      updatedAt: time,
      tags: tags,
    );
  }

  WorkTask copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? startAt,
    DateTime? endAt,
    WorkTaskStatus? status,
    int? estimatedMinutes,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Tag>? tags,
    bool clearStartAt = false,
    bool clearEndAt = false,
  }) {
    return WorkTask(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startAt: clearStartAt ? null : (startAt ?? this.startAt),
      endAt: clearEndAt ? null : (endAt ?? this.endAt),
      status: status ?? this.status,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tags: tags ?? this.tags,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId) 'id': id,
      'title': title,
      'description': description,
      'start_at': startAt?.millisecondsSinceEpoch,
      'end_at': endAt?.millisecondsSinceEpoch,
      'status': status.value,
      'estimated_minutes': estimatedMinutes,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory WorkTask.fromMap(Map<String, Object?> map, {List<Tag> tags = const []}) {
    return WorkTask(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: (map['description'] as String?) ?? '',
      startAt: _fromEpochNullable(map['start_at']),
      endAt: _fromEpochNullable(map['end_at']),
      status: WorkTaskStatus.fromValue(map['status'] as int),
      estimatedMinutes: (map['estimated_minutes'] as int?) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      tags: tags,
    );
  }

  static DateTime? _fromEpochNullable(Object? value) {
    if (value == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(value as int);
  }
}
