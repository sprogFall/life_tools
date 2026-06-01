class WorkPhotoTemplate {
  final int? id;
  final String name;
  final int sortIndex;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkPhotoTemplate({
    required this.id,
    required this.name,
    required this.sortIndex,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkPhotoTemplate.create({
    required String name,
    required int sortIndex,
    DateTime? now,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('createTemplate 需要 name');
    }
    final time = now ?? DateTime.now();
    return WorkPhotoTemplate(
      id: null,
      name: trimmed,
      sortIndex: sortIndex,
      isArchived: false,
      createdAt: time,
      updatedAt: time,
    );
  }

  WorkPhotoTemplate copyWith({
    int? id,
    String? name,
    int? sortIndex,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkPhotoTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      sortIndex: sortIndex ?? this.sortIndex,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'name': name.trim(),
      'sort_index': sortIndex,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  static WorkPhotoTemplate fromMap(Map<String, Object?> map) {
    return WorkPhotoTemplate(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      sortIndex: (map['sort_index'] as num?)?.toInt() ?? 0,
      isArchived: ((map['is_archived'] as num?)?.toInt() ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
