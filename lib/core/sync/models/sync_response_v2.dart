/// 同步决策：本次同步以哪一端数据为准
enum SyncDecision { useServer, useClient, noop }

extension SyncDecisionJson on SyncDecision {
  String toJsonValue() {
    return switch (this) {
      SyncDecision.useServer => 'use_server',
      SyncDecision.useClient => 'use_client',
      SyncDecision.noop => 'noop',
    };
  }

  static SyncDecision fromJsonValue(dynamic value) {
    final v = value is String ? value.trim().toLowerCase() : '';
    return switch (v) {
      'use_server' => SyncDecision.useServer,
      'use_client' => SyncDecision.useClient,
      'noop' => SyncDecision.noop,
      _ => SyncDecision.noop,
    };
  }
}

/// 同步响应（v2）
class SyncResponseV2 {
  final bool success;
  final String? message;
  final SyncDecision decision;
  final Map<String, Map<String, dynamic>>? toolsData;
  final DateTime serverTime;
  final int serverRevision;

  const SyncResponseV2({
    required this.success,
    this.message,
    required this.decision,
    this.toolsData,
    required this.serverTime,
    required this.serverRevision,
  });

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  factory SyncResponseV2.fromJson(Map<String, dynamic> json) {
    return SyncResponseV2(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      decision: SyncDecisionJson.fromJsonValue(json['decision']),
      toolsData: json['tools_data'] != null
          ? Map<String, Map<String, dynamic>>.from(
              (json['tools_data'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)),
              ),
            )
          : null,
      serverTime: DateTime.fromMillisecondsSinceEpoch(
        _readInt(json['server_time'], fallback: 0),
      ),
      serverRevision: _readInt(json['server_revision'], fallback: 0),
    );
  }
}

