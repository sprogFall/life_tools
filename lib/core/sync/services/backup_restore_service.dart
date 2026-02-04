import 'dart:convert';

import '../../ai/ai_config.dart';
import '../../ai/ai_config_service.dart';
import '../../obj_store/obj_store_config.dart';
import '../../obj_store/obj_store_config_service.dart';
import '../../obj_store/obj_store_secrets.dart';
import '../../registry/tool_registry.dart';
import '../../services/settings_service.dart';
import '../../utils/dev_log.dart';
import '../interfaces/tool_sync_provider.dart';
import '../models/sync_config.dart';
import 'sync_config_service.dart';
import 'tool_sync_order.dart';

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
  final ObjStoreConfigService objStoreConfigService;
  final List<ToolSyncProvider> toolProviders;

  BackupRestoreService({
    required this.aiConfigService,
    required this.syncConfigService,
    required this.settingsService,
    required this.objStoreConfigService,
    Iterable<ToolSyncProvider>? toolProviders,
  }) : toolProviders = List<ToolSyncProvider>.unmodifiable(
         toolProviders ??
             ToolRegistry.instance.tools
                 .where((t) => t.supportSync)
                 .map((t) => t.syncProvider!),
       );

  Future<Map<String, dynamic>> exportConfigAsMap({
    bool includeSensitive = false,
  }) async {
    final objStoreConfig = objStoreConfigService.config;

    Map<String, String>? objStoreSecretsJson;
    if (includeSensitive && objStoreConfig != null) {
      if (objStoreConfig.type == ObjStoreType.qiniu) {
        final secrets = objStoreConfigService.qiniuSecrets;
        if (secrets != null) {
          objStoreSecretsJson = {
            'accessKey': secrets.accessKey,
            'secretKey': secrets.secretKey,
          };
        }
      } else if (objStoreConfig.type == ObjStoreType.dataCapsule) {
        final secrets = objStoreConfigService.dataCapsuleSecrets;
        if (secrets != null) {
          objStoreSecretsJson = {
            'accessKey': secrets.accessKey,
            'secretKey': secrets.secretKey,
          };
        }
      }
    }

    final aiConfig = aiConfigService.config;
    final syncConfig = syncConfigService.config;

    final aiConfigJson = aiConfig == null
        ? null
        : Map<String, dynamic>.from(aiConfig.toMap());
    if (!includeSensitive) {
      aiConfigJson?.remove('apiKey');
    }

    final syncConfigJson = syncConfig == null
        ? null
        : Map<String, dynamic>.from(syncConfig.toMap());
    if (!includeSensitive) {
      syncConfigJson?.remove('customHeaders');
    }

    return <String, dynamic>{
      'ai_config': aiConfigJson,
      'sync_config': syncConfigJson,
      'obj_store_config': objStoreConfig?.toJson(),
      'obj_store_secrets': objStoreSecretsJson,
      'settings': {
        'default_tool_id': settingsService.defaultToolId,
        'tool_order': settingsService.toolOrder,
        'hidden_tool_ids': settingsService.hiddenToolIds,
      },
    };
  }

  Future<Map<String, Map<String, dynamic>>> exportToolsAsMap() async {
    final tools = <String, Map<String, dynamic>>{};
    for (final provider in toolProviders) {
      try {
        tools[provider.toolId] = await provider.exportData();
      } catch (e, st) {
        devLog(
          '工具 ${provider.toolId} 导出数据失败: ${e.runtimeType}',
          stackTrace: st,
        );
      }
    }
    return tools;
  }

  Future<String> exportAsJson({
    bool pretty = false,
    bool includeSensitive = false,
  }) async {
    final tools = await exportToolsAsMap();
    final configPayload = await exportConfigAsMap(
      includeSensitive: includeSensitive,
    );

    final payload = <String, dynamic>{
      'version': backupVersion,
      'exported_at': DateTime.now().millisecondsSinceEpoch,
      'sensitive_included': includeSensitive,
      ...configPayload,
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

    await restoreConfigFromMap(decoded);
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

    return _restoreToolsFromMap(toolsMap);
  }

  static Map<String, dynamic>? _readJsonMap(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> restoreConfigFromMap(Map<String, dynamic> decoded) async {
    final aiConfigMap = _readJsonMap(decoded['ai_config']);
    if (aiConfigMap != null) {
      final current = aiConfigService.config;
      final next = AiConfig(
        baseUrl:
            (aiConfigMap.containsKey('baseUrl')
                ? (aiConfigMap['baseUrl'] as String?)
                : current?.baseUrl) ??
            '',
        apiKey:
            (aiConfigMap.containsKey('apiKey')
                ? (aiConfigMap['apiKey'] as String?)
                : current?.apiKey) ??
            '',
        model:
            (aiConfigMap.containsKey('model')
                ? (aiConfigMap['model'] as String?)
                : current?.model) ??
            '',
        temperature:
            (aiConfigMap.containsKey('temperature')
                ? (aiConfigMap['temperature'] as num?)?.toDouble()
                : current?.temperature) ??
            0.7,
        maxOutputTokens:
            (aiConfigMap.containsKey('maxOutputTokens')
                ? (aiConfigMap['maxOutputTokens'] as num?)?.toInt()
                : current?.maxOutputTokens) ??
            1024,
      );
      await aiConfigService.save(next);
    }

    final syncConfigMap = _readJsonMap(decoded['sync_config']);
    if (syncConfigMap != null) {
      final incoming = SyncConfig.fromMap(syncConfigMap);
      final current = syncConfigService.config;
      final applyLastSyncTime = syncConfigMap.containsKey('lastSyncTime');
      final applyLastServerRevision = syncConfigMap.containsKey(
        'lastServerRevision',
      );
      final merged = current == null
          ? incoming
          : current.copyWith(
              userId: syncConfigMap.containsKey('userId')
                  ? incoming.userId
                  : null,
              networkType: syncConfigMap.containsKey('networkType')
                  ? incoming.networkType
                  : null,
              serverUrl: syncConfigMap.containsKey('serverUrl')
                  ? incoming.serverUrl
                  : null,
              serverPort: syncConfigMap.containsKey('serverPort')
                  ? incoming.serverPort
                  : null,
              customHeaders: syncConfigMap.containsKey('customHeaders')
                  ? incoming.customHeaders
                  : null,
              allowedWifiNames: syncConfigMap.containsKey('allowedWifiNames')
                  ? incoming.allowedWifiNames
                  : null,
              autoSyncOnStartup: syncConfigMap.containsKey('autoSyncOnStartup')
                  ? incoming.autoSyncOnStartup
                  : null,
              lastSyncTime: (applyLastSyncTime && incoming.lastSyncTime != null)
                  ? incoming.lastSyncTime
                  : null,
              clearLastSyncTime:
                  applyLastSyncTime && incoming.lastSyncTime == null,
              lastServerRevision:
                  (applyLastServerRevision &&
                      incoming.lastServerRevision != null)
                  ? incoming.lastServerRevision
                  : null,
              clearLastServerRevision:
                  applyLastServerRevision &&
                  incoming.lastServerRevision == null,
            );
      await syncConfigService.save(merged);
    }

    final objStoreConfigMap = _readJsonMap(decoded['obj_store_config']);
    if (objStoreConfigMap != null) {
      final config = ObjStoreConfig.fromJson(objStoreConfigMap);
      if (config != null) {
        if (config.type == ObjStoreType.qiniu) {
          final secretsMap = _readJsonMap(decoded['obj_store_secrets']);
          final accessKey = (secretsMap?['accessKey'] as String?)?.trim();
          final secretKey = (secretsMap?['secretKey'] as String?)?.trim();
          if (accessKey != null &&
              accessKey.isNotEmpty &&
              secretKey != null &&
              secretKey.isNotEmpty) {
            await objStoreConfigService.save(
              config,
              secrets: ObjStoreQiniuSecrets(
                accessKey: accessKey,
                secretKey: secretKey,
              ),
            );
          } else {
            await objStoreConfigService.save(
              config,
              secrets: objStoreConfigService.qiniuSecrets,
              allowMissingSecrets: true,
            );
          }
        } else if (config.type == ObjStoreType.dataCapsule) {
          final secretsMap = _readJsonMap(decoded['obj_store_secrets']);
          final accessKey = (secretsMap?['accessKey'] as String?)?.trim();
          final secretKey = (secretsMap?['secretKey'] as String?)?.trim();
          if (accessKey != null &&
              accessKey.isNotEmpty &&
              secretKey != null &&
              secretKey.isNotEmpty) {
            await objStoreConfigService.save(
              config,
              dataCapsuleSecrets: ObjStoreDataCapsuleSecrets(
                accessKey: accessKey,
                secretKey: secretKey,
              ),
            );
          } else {
            await objStoreConfigService.save(
              config,
              dataCapsuleSecrets: objStoreConfigService.dataCapsuleSecrets,
              allowMissingSecrets: true,
            );
          }
        } else if (config.type == ObjStoreType.local) {
          await objStoreConfigService.save(config);
        } else {
          await objStoreConfigService.clear();
        }
      }
    }

    final settingsMap = decoded['settings'];
    if (settingsMap is Map<String, dynamic>) {
      final defaultToolId = settingsMap['default_tool_id'] as String?;
      final toolOrderRaw = settingsMap['tool_order'];
      final toolOrder = toolOrderRaw is List
          ? toolOrderRaw.whereType<String>().toList()
          : const <String>[];
      final hasHiddenToolIds = settingsMap.containsKey('hidden_tool_ids');
      final hiddenRaw = settingsMap['hidden_tool_ids'];
      final hiddenToolIds = hiddenRaw is List
          ? hiddenRaw.whereType<String>().toList()
          : const <String>[];

      if (toolOrder.isNotEmpty) {
        final known = ToolRegistry.instance.tools.map((t) => t.id).toSet();
        final filtered = toolOrder.where(known.contains).toList();
        if (filtered.isNotEmpty) {
          await settingsService.updateToolOrder(filtered);
        }
      }

      if (hasHiddenToolIds) {
        await settingsService.setHiddenToolIds(hiddenToolIds);
      }

      if (defaultToolId != null && defaultToolId.trim().isNotEmpty) {
        await settingsService.setDefaultTool(defaultToolId);
      }
    }
  }

  Future<BackupRestoreResult> _restoreToolsFromMap(
    Map<String, dynamic> toolsMap,
  ) async {
    final providersById = {for (final p in toolProviders) p.toolId: p};

    var imported = 0;
    var skipped = 0;
    final failed = <String, String>{};

    final entries = sortToolEntries(toolsMap);

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
