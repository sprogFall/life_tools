class XiaoMiConversation {
  final int? id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const XiaoMiConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory XiaoMiConversation.create({required String title, DateTime? now}) {
    final time = now ?? DateTime.now();
    return XiaoMiConversation(
      id: null,
      title: title,
      createdAt: time,
      updatedAt: time,
    );
  }

  XiaoMiConversation copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return XiaoMiConversation(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId) 'id': id,
      'title': title,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory XiaoMiConversation.fromMap(Map<String, Object?> map) {
    return XiaoMiConversation(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }
}
