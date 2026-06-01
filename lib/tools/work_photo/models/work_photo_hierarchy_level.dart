class WorkPhotoHierarchyLevel {
  final int? id;
  final int? templateId;
  final String name;
  final int sortIndex;
  final bool isRequired;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkPhotoHierarchyLevel({
    required this.id,
    required this.templateId,
    required this.name,
    required this.sortIndex,
    required this.isRequired,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkPhotoHierarchyLevel.create({
    int? templateId,
    required String name,
    required int sortIndex,
    bool isRequired = true,
    DateTime? now,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('createHierarchyLevel 需要 name');
    }
    final time = now ?? DateTime.now();
    return WorkPhotoHierarchyLevel(
      id: null,
      templateId: templateId,
      name: trimmed,
      sortIndex: sortIndex,
      isRequired: isRequired,
      isArchived: false,
      createdAt: time,
      updatedAt: time,
    );
  }

  WorkPhotoHierarchyLevel copyWith({
    int? id,
    int? templateId,
    String? name,
    int? sortIndex,
    bool? isRequired,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkPhotoHierarchyLevel(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      sortIndex: sortIndex ?? this.sortIndex,
      isRequired: isRequired ?? this.isRequired,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'template_id': templateId,
      'name': name.trim(),
      'sort_index': sortIndex,
      'is_required': isRequired ? 1 : 0,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  static WorkPhotoHierarchyLevel fromMap(Map<String, Object?> map) {
    return WorkPhotoHierarchyLevel(
      id: map['id'] as int?,
      templateId: (map['template_id'] as num?)?.toInt(),
      name: map['name'] as String? ?? '',
      sortIndex: (map['sort_index'] as num?)?.toInt() ?? 0,
      isRequired: ((map['is_required'] as num?)?.toInt() ?? 1) == 1,
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
