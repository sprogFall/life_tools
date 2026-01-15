class Tag {
  final int? id;
  final String name;
  final int color;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Tag.create({
    required String name,
    required int color,
    String description = '',
    DateTime? now,
  }) {
    final time = now ?? DateTime.now();
    return Tag(
      id: null,
      name: name,
      color: color,
      description: description,
      createdAt: time,
      updatedAt: time,
    );
  }

  Tag copyWith({
    int? id,
    String? name,
    int? color,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId) 'id': id,
      'name': name,
      'color': color,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Tag.fromMap(Map<String, Object?> map) {
    return Tag(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as int,
      description: (map['description'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}

class TagToolAssociation {
  final int? id;
  final int tagId;
  final String toolId;
  final DateTime createdAt;

  const TagToolAssociation({
    required this.id,
    required this.tagId,
    required this.toolId,
    required this.createdAt,
  });

  factory TagToolAssociation.create({
    required int tagId,
    required String toolId,
    DateTime? now,
  }) {
    return TagToolAssociation(
      id: null,
      tagId: tagId,
      toolId: toolId,
      createdAt: now ?? DateTime.now(),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'tag_id': tagId,
      'tool_id': toolId,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory TagToolAssociation.fromMap(Map<String, Object?> map) {
    return TagToolAssociation(
      id: map['id'] as int?,
      tagId: map['tag_id'] as int,
      toolId: map['tool_id'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}