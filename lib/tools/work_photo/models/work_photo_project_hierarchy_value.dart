class WorkPhotoProjectHierarchyValue {
  final int? id;
  final int projectId;
  final int? levelId;
  final int? optionId;
  final String levelNameSnapshot;
  final String optionNameSnapshot;
  final int sortIndex;

  const WorkPhotoProjectHierarchyValue({
    required this.id,
    required this.projectId,
    required this.levelId,
    required this.optionId,
    required this.levelNameSnapshot,
    required this.optionNameSnapshot,
    required this.sortIndex,
  });

  Map<String, Object?> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'project_id': projectId,
      'level_id': levelId,
      'option_id': optionId,
      'level_name_snapshot': levelNameSnapshot,
      'option_name_snapshot': optionNameSnapshot,
      'sort_index': sortIndex,
    };
  }

  static WorkPhotoProjectHierarchyValue fromMap(Map<String, Object?> map) {
    return WorkPhotoProjectHierarchyValue(
      id: map['id'] as int?,
      projectId: (map['project_id'] as num?)?.toInt() ?? 0,
      levelId: (map['level_id'] as num?)?.toInt(),
      optionId: (map['option_id'] as num?)?.toInt(),
      levelNameSnapshot: map['level_name_snapshot'] as String? ?? '',
      optionNameSnapshot: map['option_name_snapshot'] as String? ?? '',
      sortIndex: (map['sort_index'] as num?)?.toInt() ?? 0,
    );
  }
}
