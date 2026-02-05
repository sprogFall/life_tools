import 'sync_force_decision.dart';

/// 同步请求（v2）：服务端按“游标 + 空数据保护”决定使用哪一端快照
class SyncRequestV2 {
  static const int protocolVersion = 2;

  final String userId;
  final int clientTimeMs;
  final SyncClientState clientState;
  final Map<String, Map<String, dynamic>> toolsData;
  final SyncForceDecision? forceDecision;

  const SyncRequestV2({
    required this.userId,
    required this.clientTimeMs,
    required this.clientState,
    required this.toolsData,
    this.forceDecision,
  });

  Map<String, dynamic> toJson() => {
    'protocol_version': protocolVersion,
    'user_id': userId,
    'client_time': clientTimeMs,
    'client_state': clientState.toJson(),
    if (forceDecision != null)
      'force_decision': forceDecision!.toJsonValue(),
    'tools_data': toolsData,
  };
}

class SyncClientState {
  final int? lastServerRevision;
  final bool clientIsEmpty;

  const SyncClientState({required this.clientIsEmpty, this.lastServerRevision});

  Map<String, dynamic> toJson() => {
    'last_server_revision': lastServerRevision,
    'client_is_empty': clientIsEmpty,
  };
}
