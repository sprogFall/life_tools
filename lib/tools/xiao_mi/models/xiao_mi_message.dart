import 'dart:convert';

import '../../../core/utils/dev_log.dart';

enum XiaoMiMessageRole {
  system('system'),
  user('user'),
  assistant('assistant');

  final String value;

  const XiaoMiMessageRole(this.value);

  static XiaoMiMessageRole fromValue(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final role in XiaoMiMessageRole.values) {
      if (role.value == normalized) return role;
    }
    return XiaoMiMessageRole.user;
  }
}

class XiaoMiMessage {
  final int? id;
  final int conversationId;
  final XiaoMiMessageRole role;
  final String content;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const XiaoMiMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.metadata,
    required this.createdAt,
  });

  factory XiaoMiMessage.create({
    required int conversationId,
    required XiaoMiMessageRole role,
    required String content,
    Map<String, dynamic>? metadata,
    required DateTime createdAt,
  }) {
    return XiaoMiMessage(
      id: null,
      conversationId: conversationId,
      role: role,
      content: content,
      metadata: metadata,
      createdAt: createdAt,
    );
  }

  XiaoMiMessage copyWith({
    int? id,
    int? conversationId,
    XiaoMiMessageRole? role,
    String? content,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
  }) {
    return XiaoMiMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId) 'id': id,
      'conversation_id': conversationId,
      'role': role.value,
      'content': content,
      'metadata': metadata == null ? null : jsonEncode(metadata),
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory XiaoMiMessage.fromMap(Map<String, Object?> map) {
    final rawMetadata = map['metadata'] as String?;
    Map<String, dynamic>? metadata;
    if (rawMetadata != null && rawMetadata.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMetadata);
        if (decoded is Map<String, dynamic>) {
          metadata = decoded;
        }
      } catch (error, stackTrace) {
        devLog(
          'xiao_mi_message_decode_metadata_failed',
          error: error,
          stackTrace: stackTrace,
        );
        metadata = null;
      }
    }

    return XiaoMiMessage(
      id: map['id'] as int?,
      conversationId: map['conversation_id'] as int,
      role: XiaoMiMessageRole.fromValue((map['role'] as String?) ?? ''),
      content: (map['content'] as String?) ?? '',
      metadata: metadata,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
