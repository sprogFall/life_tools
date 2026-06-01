enum WorkPhotoProjectStatus {
  active(0),
  completed(1),
  archived(2);

  final int value;
  const WorkPhotoProjectStatus(this.value);

  static WorkPhotoProjectStatus fromValue(int value) {
    return WorkPhotoProjectStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => WorkPhotoProjectStatus.active,
    );
  }
}

class WorkPhotoProject {
  final int? id;
  final int? templateId;
  final String templateNameSnapshot;
  final String name;
  final WorkPhotoProjectStatus status;
  final String note;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkPhotoProject({
    required this.id,
    required this.templateId,
    required this.templateNameSnapshot,
    required this.name,
    required this.status,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkPhotoProject.create({
    int? templateId,
    String templateNameSnapshot = '',
    required String name,
    required String note,
    DateTime? now,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('createProject 需要 name');
    }
    final time = now ?? DateTime.now();
    return WorkPhotoProject(
      id: null,
      templateId: templateId,
      templateNameSnapshot: templateNameSnapshot.trim(),
      name: trimmed,
      status: WorkPhotoProjectStatus.active,
      note: note.trim(),
      createdAt: time,
      updatedAt: time,
    );
  }

  WorkPhotoProject copyWith({
    int? id,
    int? templateId,
    String? templateNameSnapshot,
    String? name,
    WorkPhotoProjectStatus? status,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkPhotoProject(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      templateNameSnapshot: templateNameSnapshot ?? this.templateNameSnapshot,
      name: name ?? this.name,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'template_id': templateId,
      'template_name_snapshot': templateNameSnapshot.trim(),
      'name': name.trim(),
      'status': status.value,
      'note': note.trim(),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  static WorkPhotoProject fromMap(Map<String, Object?> map) {
    return WorkPhotoProject(
      id: map['id'] as int?,
      templateId: (map['template_id'] as num?)?.toInt(),
      templateNameSnapshot: map['template_name_snapshot'] as String? ?? '',
      name: map['name'] as String? ?? '',
      status: WorkPhotoProjectStatus.fromValue(
        (map['status'] as num?)?.toInt() ?? 0,
      ),
      note: map['note'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
