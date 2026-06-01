class WorkPhotoProjectItem {
  final int? id;
  final int projectId;
  final int? sourceItemId;
  final String nameSnapshot;
  final int sortIndex;
  final int minCount;
  final int? maxCount;

  const WorkPhotoProjectItem({
    required this.id,
    required this.projectId,
    required this.sourceItemId,
    required this.nameSnapshot,
    required this.sortIndex,
    required this.minCount,
    required this.maxCount,
  });

  Map<String, Object?> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'project_id': projectId,
      'source_item_id': sourceItemId,
      'name_snapshot': nameSnapshot,
      'sort_index': sortIndex,
      'min_count': minCount,
      'max_count': maxCount,
    };
  }

  static WorkPhotoProjectItem fromMap(Map<String, Object?> map) {
    return WorkPhotoProjectItem(
      id: map['id'] as int?,
      projectId: (map['project_id'] as num?)?.toInt() ?? 0,
      sourceItemId: (map['source_item_id'] as num?)?.toInt(),
      nameSnapshot: map['name_snapshot'] as String? ?? '',
      sortIndex: (map['sort_index'] as num?)?.toInt() ?? 0,
      minCount: (map['min_count'] as num?)?.toInt() ?? 1,
      maxCount: (map['max_count'] as num?)?.toInt(),
    );
  }
}
