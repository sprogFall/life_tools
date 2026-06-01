class WorkPhotoHierarchyOption {
  final int? id;
  final int levelId;
  final int? parentOptionId;
  final String name;
  final int sortIndex;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkPhotoHierarchyOption({
    required this.id,
    required this.levelId,
    required this.parentOptionId,
    required this.name,
    required this.sortIndex,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkPhotoHierarchyOption.create({
    required int levelId,
    required int? parentOptionId,
    required String name,
    required int sortIndex,
    DateTime? now,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('createHierarchyOption 需要 name');
    }
    final time = now ?? DateTime.now();
    return WorkPhotoHierarchyOption(
      id: null,
      levelId: levelId,
      parentOptionId: parentOptionId,
      name: trimmed,
      sortIndex: sortIndex,
      isArchived: false,
      createdAt: time,
      updatedAt: time,
    );
  }

  WorkPhotoHierarchyOption copyWith({
    int? id,
    int? levelId,
    int? parentOptionId,
    bool clearParentOptionId = false,
    String? name,
    int? sortIndex,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkPhotoHierarchyOption(
      id: id ?? this.id,
      levelId: levelId ?? this.levelId,
      parentOptionId: clearParentOptionId
          ? null
          : (parentOptionId ?? this.parentOptionId),
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
      'level_id': levelId,
      'parent_option_id': parentOptionId,
      'name': name.trim(),
      'sort_index': sortIndex,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  static WorkPhotoHierarchyOption fromMap(Map<String, Object?> map) {
    return WorkPhotoHierarchyOption(
      id: map['id'] as int?,
      levelId: (map['level_id'] as num?)?.toInt() ?? 0,
      parentOptionId: (map['parent_option_id'] as num?)?.toInt(),
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
