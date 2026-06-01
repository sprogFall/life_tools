class WorkPhotoAsset {
  final int? id;
  final int projectId;
  final int projectItemId;
  final String relativePath;
  final String originalFilename;
  final String mimeType;
  final int fileSize;
  final int? width;
  final int? height;
  final DateTime takenAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkPhotoAsset({
    required this.id,
    required this.projectId,
    required this.projectItemId,
    required this.relativePath,
    required this.originalFilename,
    required this.mimeType,
    required this.fileSize,
    required this.width,
    required this.height,
    required this.takenAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'project_id': projectId,
      'project_item_id': projectItemId,
      'relative_path': relativePath,
      'original_filename': originalFilename,
      'mime_type': mimeType,
      'file_size': fileSize,
      'width': width,
      'height': height,
      'taken_at': takenAt.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  static WorkPhotoAsset fromMap(Map<String, Object?> map) {
    return WorkPhotoAsset(
      id: map['id'] as int?,
      projectId: (map['project_id'] as num?)?.toInt() ?? 0,
      projectItemId: (map['project_item_id'] as num?)?.toInt() ?? 0,
      relativePath: map['relative_path'] as String? ?? '',
      originalFilename: map['original_filename'] as String? ?? '',
      mimeType: map['mime_type'] as String? ?? 'image/jpeg',
      fileSize: (map['file_size'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      takenAt: DateTime.fromMillisecondsSinceEpoch(
        (map['taken_at'] as num?)?.toInt() ?? 0,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
