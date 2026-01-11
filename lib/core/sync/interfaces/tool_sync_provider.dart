/// 工具同步数据提供者接口
///
/// 工具实现此接口，即可接入同步功能。
/// 不实现此接口的工具不受影响，保持向后兼容。
abstract class ToolSyncProvider {
  /// 工具唯一标识（必须与 ToolInfo.id 一致）
  String get toolId;

  /// 导出工具的所有数据为JSON格式
  ///
  /// 返回的Map结构由各工具自行定义，建议包含：
  /// - version: 数据版本号（用于后续兼容性处理）
  /// - data: 实际数据
  ///
  /// 示例（WorkLog）：
  /// {
  ///   "version": 1,
  ///   "data": {
  ///     "tasks": [...],
  ///     "time_entries": [...],
  ///     "operation_logs": [...]
  ///   }
  /// }
  Future<Map<String, dynamic>> exportData();

  /// 导入数据并覆盖本地
  ///
  /// @param data 服务端返回的工具数据（JSON格式）
  /// @throws Exception 导入失败时抛出异常
  ///
  /// 注意：
  /// 1. 导入前应该进行数据验证
  /// 2. 建议使用事务确保原子性
  /// 3. ID冲突处理策略由工具自行决定（建议：服务端ID优先）
  Future<void> importData(Map<String, dynamic> data);
}
