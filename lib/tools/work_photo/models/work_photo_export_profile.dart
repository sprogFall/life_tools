class WorkPhotoExportProfile {
  final int? id;
  final String name;
  final String folderTemplate;
  final String fileTemplate;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkPhotoExportProfile({
    required this.id,
    required this.name,
    required this.folderTemplate,
    required this.fileTemplate,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkPhotoExportProfile.create({
    required String name,
    String folderTemplate = '',
    String fileTemplate = '',
    bool isDefault = false,
    DateTime? now,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('createExportProfile 需要 name');
    }
    final time = now ?? DateTime.now();
    return WorkPhotoExportProfile(
      id: null,
      name: trimmed,
      folderTemplate: folderTemplate.trim(),
      fileTemplate: fileTemplate.trim(),
      isDefault: isDefault,
      createdAt: time,
      updatedAt: time,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return {
      if (includeId) 'id': id,
      'name': name,
      'folder_template': folderTemplate,
      'file_template': fileTemplate,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  static WorkPhotoExportProfile fromMap(Map<String, Object?> map) {
    return WorkPhotoExportProfile(
      id: map['id'] as int?,
      name: map['name'] as String? ?? '',
      folderTemplate: map['folder_template'] as String? ?? '',
      fileTemplate: map['file_template'] as String? ?? '',
      isDefault: ((map['is_default'] as num?)?.toInt() ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updated_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
