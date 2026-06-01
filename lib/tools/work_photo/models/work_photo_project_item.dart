import 'dart:convert';

class WorkPhotoProjectItem {
  final int? id;
  final int projectId;
  final int? sourceItemId;
  final String nameSnapshot;
  final List<String> hierarchyPathSnapshot;
  final int sortIndex;
  final int minCount;
  final int? maxCount;

  const WorkPhotoProjectItem({
    required this.id,
    required this.projectId,
    required this.sourceItemId,
    required this.nameSnapshot,
    this.hierarchyPathSnapshot = const [],
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
      'hierarchy_path_snapshot': jsonEncode(hierarchyPathSnapshot),
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
      hierarchyPathSnapshot: _parseHierarchyPathSnapshot(
        map['hierarchy_path_snapshot'],
      ),
      sortIndex: (map['sort_index'] as num?)?.toInt() ?? 0,
      minCount: (map['min_count'] as num?)?.toInt() ?? 1,
      maxCount: (map['max_count'] as num?)?.toInt(),
    );
  }

  static List<String> _parseHierarchyPathSnapshot(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
