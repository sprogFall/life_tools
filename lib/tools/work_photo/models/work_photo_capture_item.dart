class WorkPhotoCaptureItem {
  final int? id;
  final int? templateId;
  final int? parentLevelId;
  final String name;
  final int sortIndex;
  final int minCount;
  final int? maxCount;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkPhotoCaptureItem({
    required this.id,
    required this.templateId,
    required this.parentLevelId,
    required this.name,
    required this.sortIndex,
    required this.minCount,
    required this.maxCount,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkPhotoCaptureItem.create({
    int? templateId,
    int? parentLevelId,
    required String name,
    required int sortIndex,
    int minCount = 1,
    int? maxCount,
    DateTime? now,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('createCaptureItem 需要 name');
    }
    if (minCount < 0) {
      throw ArgumentError('minCount 不能小于 0');
    }
    if (maxCount != null && maxCount < minCount) {
      throw ArgumentError('maxCount 不能小于 minCount');
    }
    final time = now ?? DateTime.now();
    return WorkPhotoCaptureItem(
      id: null,
      templateId: templateId,
      parentLevelId: parentLevelId,
      name: trimmed,
      sortIndex: sortIndex,
      minCount: minCount,
      maxCount: maxCount,
      isArchived: false,
      createdAt: time,
      updatedAt: time,
    );
  }

  WorkPhotoCaptureItem copyWith({
    int? id,
    int? templateId,
    int? parentLevelId,
    bool clearParentLevelId = false,
    String? name,
    int? sortIndex,
    int? minCount,
    int? maxCount,
    bool clearMaxCount = false,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkPhotoCaptureItem(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      parentLevelId: clearParentLevelId
          ? null
          : (parentLevelId ?? this.parentLevelId),
      name: name ?? this.name,
      sortIndex: sortIndex ?? this.sortIndex,
      minCount: minCount ?? this.minCount,
      maxCount: clearMaxCount ? null : (maxCount ?? this.maxCount),
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'template_id': templateId,
      'parent_level_id': parentLevelId,
      'name': name.trim(),
      'sort_index': sortIndex,
      'min_count': minCount,
      'max_count': maxCount,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  static WorkPhotoCaptureItem fromMap(Map<String, Object?> map) {
    return WorkPhotoCaptureItem(
      id: map['id'] as int?,
      templateId: (map['template_id'] as num?)?.toInt(),
      parentLevelId: (map['parent_level_id'] as num?)?.toInt(),
      name: map['name'] as String? ?? '',
      sortIndex: (map['sort_index'] as num?)?.toInt() ?? 0,
      minCount: (map['min_count'] as num?)?.toInt() ?? 1,
      maxCount: (map['max_count'] as num?)?.toInt(),
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
