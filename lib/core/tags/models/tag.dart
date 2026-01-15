class Tag {
  final int? id;
  final String name;
  final int? color;
  final int sortIndex;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.sortIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Tag.create({required String name, int? color, DateTime? now}) {
    final time = now ?? DateTime.now();
    return Tag(
      id: null,
      name: name,
      color: color,
      sortIndex: 0,
      createdAt: time,
      updatedAt: time,
    );
  }

  Tag copyWith({
    int? id,
    String? name,
    int? color,
    int? sortIndex,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortIndex: sortIndex ?? this.sortIndex,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId) 'id': id,
      'name': name,
      'color': color,
      'sort_index': sortIndex,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Tag.fromMap(Map<String, Object?> map) {
    return Tag(
      id: map['id'] as int?,
      name: map['name'] as String,
      color: map['color'] as int?,
      sortIndex: (map['sort_index'] as int?) ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
