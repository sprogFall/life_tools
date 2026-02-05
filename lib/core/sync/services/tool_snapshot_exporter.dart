import '../../utils/dev_log.dart';
import '../interfaces/tool_sync_provider.dart';

class ToolSnapshotExporter {
  const ToolSnapshotExporter._();

  static Future<Map<String, Map<String, dynamic>>> exportAll({
    required Iterable<ToolSyncProvider> providers,
    required String failureSuffix,
    bool requireDataKey = true,
  }) async {
    final snapshots = <String, Map<String, dynamic>>{};
    final failed = <String>[];

    for (final provider in providers) {
      final toolId = provider.toolId;
      try {
        final exported = await provider.exportData();

        if (requireDataKey) {
          final hasDataKey = exported.containsKey('data');
          if (!hasDataKey || exported['data'] == null) {
            failed.add('$toolId（缺少 data 字段）');
            devLog('工具 $toolId 导出数据缺少 data 字段');
            continue;
          }
        }

        snapshots[toolId] = exported;
      } catch (e, st) {
        failed.add(toolId);
        devLog('工具 $toolId 导出数据失败: ${e.runtimeType}', stackTrace: st);
      }
    }

    if (failed.isNotEmpty) {
      throw Exception('工具数据导出失败：${failed.join("，")}$failureSuffix');
    }

    return snapshots;
  }
}

