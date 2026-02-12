import 'sync_response_v2.dart';

/// 同步记录（服务端审计日志）
class SyncRecord {
  final int id;
  final String userId;
  final int protocolVersion;
  final SyncDecision decision;
  final DateTime serverTime;
  final DateTime? clientTime;
  final int clientUpdatedAtMs;
  final int serverUpdatedAtMsBefore;
  final int serverUpdatedAtMsAfter;
  final int serverRevisionBefore;
  final int serverRevisionAfter;
  final Map<String, dynamic> diffSummary;
  final Map<String, dynamic>? diff;

  const SyncRecord({
    required this.id,
    required this.userId,
    required this.protocolVersion,
    required this.decision,
    required this.serverTime,
    required this.clientTime,
    required this.clientUpdatedAtMs,
    required this.serverUpdatedAtMsBefore,
    required this.serverUpdatedAtMsAfter,
    required this.serverRevisionBefore,
    required this.serverRevisionAfter,
    required this.diffSummary,
    this.diff,
  });

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  factory SyncRecord.fromJson(Map<String, dynamic> json) {
    final serverTimeMs = _readInt(json['server_time'], fallback: 0);
    final clientTimeMs = json['client_time'];
    final clientTimeValue = clientTimeMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            _readInt(clientTimeMs, fallback: 0),
          );

    return SyncRecord(
      id: _readInt(json['id'], fallback: 0),
      userId: (json['user_id'] as String?) ?? '',
      protocolVersion: _readInt(json['protocol_version'], fallback: 0),
      decision: SyncDecisionJson.fromJsonValue(json['decision']),
      serverTime: DateTime.fromMillisecondsSinceEpoch(serverTimeMs),
      clientTime: clientTimeValue,
      clientUpdatedAtMs: _readInt(json['client_updated_at_ms'], fallback: 0),
      serverUpdatedAtMsBefore: _readInt(
        json['server_updated_at_ms_before'],
        fallback: 0,
      ),
      serverUpdatedAtMsAfter: _readInt(
        json['server_updated_at_ms_after'],
        fallback: 0,
      ),
      serverRevisionBefore: _readInt(
        json['server_revision_before'],
        fallback: 0,
      ),
      serverRevisionAfter: _readInt(json['server_revision_after'], fallback: 0),
      diffSummary: _readMap(json['diff_summary']),
      diff: json['diff'] is Map ? _readMap(json['diff']) : null,
    );
  }
}
