class WorkLogConstants {
  WorkLogConstants._();

  static const toolId = 'work_log';
  static const toolName = '工作记录';

  static const defaultOperationLogRetentionLimit = 10;
  static const minOperationLogRetentionLimit = 1;
  static const maxOperationLogRetentionLimit = 200;
  static const operationLogRetentionLimitOptions = <int>[10, 20, 50, 100];

  // 兼容历史常量名：默认保留条数。
  static const maxOperationLogRecords = defaultOperationLogRetentionLimit;
}

class WorkLogTagCategories {
  WorkLogTagCategories._();

  /// 工作记录的“标签”语义：归属（项目/客户/团队/OKR 等）
  static const affiliation = 'affiliation';
}
