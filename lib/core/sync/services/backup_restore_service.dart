import 'dart:convert';

import '../../ai/ai_config.dart';
import '../../ai/ai_config_service.dart';
import '../../registry/tool_registry.dart';
import '../../services/settings_service.dart';
import '../interfaces/tool_sync_provider.dart';
import '../models/sync_config.dart';
import 'sync_config_service.dart';

class BackupRestoreResult {
  final int importedTools;
  final int skippedTools;
  final Map<String, String> failedTools;

  const BackupRestoreResult({
    required this.importedTools,
    required this.skippedTools,
    required this.failedTools,
  });
}

/// 备份与还原（导出为 JSON / 从 JSON 导入）
///
/// 设计原则：
/// - 工具数据/配置走 ToolSyncProvider 公共接口（与“数据同步”一致）
/// - 应用配置分别由各 Service 管理（AiConfigService/SyncConfigService/SettingsService）
class BackupRestoreService {
  static const int backupVersion = 1;

  final AiConfigService aiConfigService;
  final SyncConfigService syncConfigService;
  final SettingsService settingsService;
  final List<ToolSyncProvider> toolProviders;

  BackupRestoreService({
    required this.aiConfigService,
    required this.syncConfigService,
    required this.settingsService,
    Iterable<ToolSyncProvider>? toolProviders,
  }) : toolProviders = List<ToolSyncProvider>.unmodifiable(
         toolProviders ??
             ToolRegistry.instance.tools
                 .where((t) => t.supportSync)
                 .map((t) => t.syncProvider!),
       );

  Future<String> exportAsJson({bool pretty = false}) async {
    final tools = <String, Map<String, dynamic>>{};

    for (final provider in toolProviders) {
      try {
        tools[provider.toolId] = await provider.exportData();
      } catch (_) {
        // 单个工具失败不影响整体导出
      }
    }

    final payload = <String, dynamic>{
      'version': backupVersion,
      'exported_at': DateTime.now().millisecondsSinceEpoch,
      'ai_config': aiConfigService.config?.toMap(),
      'sync_config': syncConfigService.config?.toMap(),
      'settings': {
        'default_tool_id': settingsService.defaultToolId,
        'tool_order': settingsService.toolOrder,
      },
      'tools': tools,
    };

    if (!pretty) return jsonEncode(payload);
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<BackupRestoreResult> restoreFromJson(String jsonText) async {
    final text = jsonText.trim();
    if (text.isEmpty) {
      throw const FormatException('JSON 为空');
    }

    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON 根节点必须为对象');
    }

    final version = decoded['version'] as int?;
    if (version != backupVersion) {
      throw FormatException('不支持的备份版本: $version');
    }

    final aiConfigMap = decoded['ai_config'];
    if (aiConfigMap is Map<String, dynamic>) {
      final config = AiConfig.fromMap(aiConfigMap);
      await aiConfigService.save(config);
    }

    final syncConfigMap = decoded['sync_config'];
    if (syncConfigMap is Map<String, dynamic>) {
      final config = SyncConfig.fromMap(syncConfigMap);
      await syncConfigService.save(config);
    }

    final settingsMap = decoded['settings'];
    if (settingsMap is Map<String, dynamic>) {
      final defaultToolId = settingsMap['default_tool_id'] as String?;
      final toolOrderRaw = settingsMap['tool_order'];
      final toolOrder = toolOrderRaw is List
          ? toolOrderRaw.whereType<String>().toList()
          : const <String>[];

      if (toolOrder.isNotEmpty) {
        final known = ToolRegistry.instance.tools.map((t) => t.id).toSet();
        final filtered = toolOrder.where(known.contains).toList();
        if (filtered.isNotEmpty) {
          await settingsService.updateToolOrder(filtered);
        }
      }

      if (defaultToolId != null && defaultToolId.trim().isNotEmpty) {
        await settingsService.setDefaultTool(defaultToolId);
      }
    }

    final toolsNode = decoded['tools'];
    final toolsMap = toolsNode is Map
        ? Map<String, dynamic>.from(toolsNode)
        : null;

    if (toolsMap == null) {
      return const BackupRestoreResult(
        importedTools: 0,
        skippedTools: 0,
        failedTools: {},
      );
    }

    final providersById = {for (final p in toolProviders) p.toolId: p};

    var imported = 0;
    var skipped = 0;
    final failed = <String, String>{};

    final entries = toolsMap.entries.toList()
      ..sort((a, b) {
        if (a.key == 'tag_manager' && b.key != 'tag_manager') return -1;
        if (b.key == 'tag_manager' && a.key != 'tag_manager') return 1;
        return 0;
      });

    for (final entry in entries) {
      final toolId = entry.key;
      final data = entry.value;

      final provider = providersById[toolId];
      if (provider == null) {
        skipped++;
        continue;
      }

      if (data is! Map) {
        failed[toolId] = '工具数据不是对象';
        continue;
      }

      try {
        await provider.importData(Map<String, dynamic>.from(data));
        imported++;
      } catch (e) {
        failed[toolId] = e.toString();
      }
    }

    return BackupRestoreResult(
      importedTools: imported,
      skippedTools: skipped,
      failedTools: failed,
    );
  }
}
