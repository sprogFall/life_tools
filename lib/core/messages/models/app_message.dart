class AppMessage {
  final int? id;
  final String toolId;
  final String title;
  final String body;
  final String? dedupeKey;
  final DateTime createdAt;

  const AppMessage({
    this.id,
    required this.toolId,
    required this.title,
    required this.body,
    required this.dedupeKey,
    required this.createdAt,
  });

  Map<String, Object?> toMap({bool includeId = true}) {
    final map = <String, Object?>{
      'tool_id': toolId,
      'title': title,
      'body': body,
      'dedupe_key': dedupeKey,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
    if (includeId && id != null) map['id'] = id;
    return map;
  }

  static AppMessage fromMap(Map<String, Object?> map) {
    return AppMessage(
      id: map['id'] as int?,
      toolId: (map['tool_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      dedupeKey: map['dedupe_key'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}

