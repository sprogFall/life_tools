/// 操作类型枚举
enum OperationType {
  createTask(0),
  updateTask(1),
  deleteTask(2),
  createTimeEntry(3),
  updateTimeEntry(4),
  deleteTimeEntry(5);

  final int value;
  const OperationType(this.value);

  static OperationType fromValue(int value) {
    return OperationType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => OperationType.createTask,
    );
  }

  String get displayName {
    return switch (this) {
      OperationType.createTask => '创建任务',
      OperationType.updateTask => '更新任务',
      OperationType.deleteTask => '删除任务',
      OperationType.createTimeEntry => '创建工时',
      OperationType.updateTimeEntry => '更新工时',
      OperationType.deleteTimeEntry => '删除工时',
    };
  }
}

/// 操作目标类型
enum TargetType {
  task(0),
  timeEntry(1);

  final int value;
  const TargetType(this.value);

  static TargetType fromValue(int value) {
    return TargetType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => TargetType.task,
    );
  }
}

/// 操作日志模型
class OperationLog {
  final int? id;
  final OperationType operationType;
  final TargetType targetType;
  final int targetId;
  final String targetTitle;
  final String? beforeSnapshot;
  final String? afterSnapshot;
  final String summary;
  final DateTime createdAt;

  const OperationLog({
    required this.id,
    required this.operationType,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    required this.beforeSnapshot,
    required this.afterSnapshot,
    required this.summary,
    required this.createdAt,
  });

  factory OperationLog.create({
    required OperationType operationType,
    required TargetType targetType,
    required int targetId,
    required String targetTitle,
    String? beforeSnapshot,
    String? afterSnapshot,
    required String summary,
    DateTime? now,
  }) {
    return OperationLog(
      id: null,
      operationType: operationType,
      targetType: targetType,
      targetId: targetId,
      targetTitle: targetTitle,
      beforeSnapshot: beforeSnapshot,
      afterSnapshot: afterSnapshot,
      summary: summary,
      createdAt: now ?? DateTime.now(),
    );
  }

  Map<String, Object?> toMap({bool includeId = true}) {
    return <String, Object?>{
      if (includeId) 'id': id,
      'operation_type': operationType.value,
      'target_type': targetType.value,
      'target_id': targetId,
      'target_title': targetTitle,
      'before_snapshot': beforeSnapshot,
      'after_snapshot': afterSnapshot,
      'summary': summary,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory OperationLog.fromMap(Map<String, Object?> map) {
    return OperationLog(
      id: map['id'] as int?,
      operationType: OperationType.fromValue(map['operation_type'] as int),
      targetType: TargetType.fromValue(map['target_type'] as int),
      targetId: map['target_id'] as int,
      targetTitle: (map['target_title'] as String?) ?? '',
      beforeSnapshot: map['before_snapshot'] as String?,
      afterSnapshot: map['after_snapshot'] as String?,
      summary: (map['summary'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
}
