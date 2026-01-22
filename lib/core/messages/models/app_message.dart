class AppMessage {
  final int? id;
  final String toolId;
  final String title;
  final String body;
  final String? route;
  final String? dedupeKey;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isRead;
  final DateTime? readAt;

  const AppMessage({
    this.id,
    required this.toolId,
    required this.title,
    required this.body,
    required this.route,
    required this.dedupeKey,
    required this.createdAt,
    required this.expiresAt,
    required this.isRead,
    required this.readAt,
  });

  Map<String, Object?> toMap({bool includeId = true}) {
    final map = <String, Object?>{
      'tool_id': toolId,
      'title': title,
      'body': body,
      'route': route,
      'dedupe_key': dedupeKey,
      'created_at': createdAt.millisecondsSinceEpoch,
      'expires_at': expiresAt?.millisecondsSinceEpoch,
      'is_read': isRead ? 1 : 0,
      'read_at': readAt?.millisecondsSinceEpoch,
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
      route: map['route'] as String?,
      dedupeKey: map['dedupe_key'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      expiresAt: (map['expires_at'] as int?) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int),
      isRead: (map['is_read'] as int?) == 1,
      readAt: (map['read_at'] as int?) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['read_at'] as int),
    );
  }
}
