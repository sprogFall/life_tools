import 'sync_force_decision.dart';

/// 同步请求数据结构
class SyncRequest {
  final String userId;
  final Map<String, Map<String, dynamic>> toolsData; // key: toolId, value: 工具数据
  final SyncForceDecision? forceDecision;

  const SyncRequest({
    required this.userId,
    required this.toolsData,
    this.forceDecision,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    if (forceDecision != null)
      'force_decision': forceDecision!.toJsonValue(),
    'tools_data': toolsData,
  };
}
