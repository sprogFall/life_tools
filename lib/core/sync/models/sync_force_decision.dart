/// 同步强制决策：用于“覆盖本地/覆盖服务端”等需要明确方向的场景。
enum SyncForceDecision { useServer, useClient }

extension SyncForceDecisionJson on SyncForceDecision {
  String toJsonValue() {
    return switch (this) {
      SyncForceDecision.useServer => 'use_server',
      SyncForceDecision.useClient => 'use_client',
    };
  }

  static SyncForceDecision? tryFromJsonValue(dynamic value) {
    final v = value is String ? value.trim().toLowerCase() : '';
    return switch (v) {
      'use_server' => SyncForceDecision.useServer,
      'use_client' => SyncForceDecision.useClient,
      _ => null,
    };
  }
}
