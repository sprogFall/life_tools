import 'package:flutter/foundation.dart';

import '../../ai/ai_config_service.dart';
import '../../obj_store/obj_store_config_service.dart';
import '../../registry/tool_registry.dart';
import '../../services/settings_service.dart';
import '../interfaces/tool_sync_provider.dart';
import '../models/sync_config.dart';
import '../models/sync_force_decision.dart';
import '../models/sync_request.dart';
import '../models/sync_request_v2.dart';
import '../models/sync_response_v2.dart';
import 'app_config_sync_provider.dart';
import 'backup_restore_service.dart';
import 'sync_api_client.dart';
import 'sync_config_service.dart';
import 'sync_local_state_service.dart';
import 'sync_network_precheck.dart';
import 'tool_sync_order.dart';
import 'wifi_service.dart';

/// 同步状态
enum SyncState {
  idle, // 空闲
  checking, // 检查条件
  syncing, // 同步中
  success, // 同步成功
  failed, // 同步失败
}

/// 同步触发来源（用于区分自动同步与手动同步的提示文案/策略）
enum SyncTrigger { manual, auto }

class SyncUserMismatch {
  final String localUserId;
  final String serverUserId;

  const SyncUserMismatch({
    required this.localUserId,
    required this.serverUserId,
  });
}

/// 同步核心服务
class SyncService extends ChangeNotifier {
  final SyncConfigService _configService;
  final SyncLocalStateService _localStateService;
  final WifiService _wifiService;
  final SyncApiClient _apiClient;
  final List<ToolSyncProvider> _toolProviders;

  SyncState _state = SyncState.idle;
  String? _lastError;
  bool _isSyncing = false; // 同步锁，防止并发

  SyncState get state => _state;
  String? get lastError => _lastError;
  bool get isSyncing => _isSyncing;

  SyncService({
    required SyncConfigService configService,
    required SyncLocalStateService localStateService,
    required AiConfigService aiConfigService,
    required SettingsService settingsService,
    required ObjStoreConfigService objStoreConfigService,
    WifiService? wifiService,
    SyncApiClient? apiClient,
    Iterable<ToolSyncProvider>? toolProviders,
  }) : _configService = configService,
       _localStateService = localStateService,
       _wifiService = wifiService ?? WifiService(),
       _apiClient = apiClient ?? SyncApiClient(),
       _toolProviders = List<ToolSyncProvider>.unmodifiable(
         _buildToolProviders(
           aiConfigService: aiConfigService,
           syncConfigService: configService,
           settingsService: settingsService,
           objStoreConfigService: objStoreConfigService,
           toolProviders: toolProviders,
         ),
       );

  static List<ToolSyncProvider> _buildToolProviders({
    required AiConfigService aiConfigService,
    required SyncConfigService syncConfigService,
    required SettingsService settingsService,
    required ObjStoreConfigService objStoreConfigService,
    Iterable<ToolSyncProvider>? toolProviders,
  }) {
    final baseProviders =
        toolProviders ??
        ToolRegistry.instance.tools
            .where((t) => t.supportSync)
            .map((t) => t.syncProvider!);

    final base = List<ToolSyncProvider>.from(baseProviders);

    final backupRestoreService = BackupRestoreService(
      aiConfigService: aiConfigService,
      syncConfigService: syncConfigService,
      settingsService: settingsService,
      objStoreConfigService: objStoreConfigService,
      toolProviders: base,
    );

    return [
      ...base,
      AppConfigSyncProvider(backupRestoreService: backupRestoreService),
    ];
  }

  SyncUserMismatch? getUserMismatch({SyncConfig? config}) {
    final cfg = config ?? _configService.config;
    if (cfg == null) return null;

    final serverUserId = cfg.userId.trim();
    if (serverUserId.isEmpty) return null;

    final localUserId = _localStateService.localUserId?.trim();
    if (localUserId == null || localUserId.isEmpty) return null;

    if (localUserId == serverUserId) return null;

    return SyncUserMismatch(localUserId: localUserId, serverUserId: serverUserId);
  }

  /// 执行同步（主入口）
  Future<bool> sync({
    SyncTrigger trigger = SyncTrigger.manual,
    SyncForceDecision? forceDecision,
  }) async {
    if (_isSyncing) {
      _lastError = '同步正在进行中，请稍后';
      notifyListeners();
      return false;
    }

    _isSyncing = true;
    _setState(SyncState.checking);
    _lastError = null;

    try {
      // 1. 检查配置
      final config = _configService.config;
      if (config == null || !config.isValid) {
        _lastError = '同步配置未设置或不完整';
        _setState(SyncState.failed);
        return false;
      }

      final mismatch = getUserMismatch(config: config);
      if (mismatch != null && forceDecision == null) {
        _lastError = switch (trigger) {
          SyncTrigger.auto =>
            '用户不匹配，无法自动同步：本地数据用户（${mismatch.localUserId}）与当前同步用户（${mismatch.serverUserId}）不一致。\n'
                '为避免覆盖服务端数据，请前往“数据同步”页面手动同步并选择“覆盖本地/覆盖服务端”。',
          SyncTrigger.manual =>
            '检测到用户不匹配：本地数据用户（${mismatch.localUserId}）与当前同步用户（${mismatch.serverUserId}）不一致。\n'
                '为避免覆盖服务端数据，请在同步页请选择覆盖方向（覆盖本地 / 覆盖服务端）。',
        };
        _setState(SyncState.failed);
        return false;
      }

      // 2. 检查网络条件
      if (!await _checkNetworkCondition(config)) {
        _setState(SyncState.failed);
        return false;
      }

      // 3. 收集工具数据
      _setState(SyncState.syncing);
      final toolsData = (forceDecision == SyncForceDecision.useServer)
          ? const <String, Map<String, dynamic>>{}
          : await _collectToolsData();

      if (toolsData.isEmpty && forceDecision != SyncForceDecision.useServer) {
        // 没有工具支持同步：视为成功
        _setState(SyncState.success);
        await _configService.updateLastSyncTime(DateTime.now());
        await _localStateService.setLocalUserId(config.userId);
        return true;
      }

      // 4. 调用同步 API（优先 v2，服务端不支持则回退 v1）
      final v2Response = await _trySyncV2(
        config: config,
        toolsData: toolsData,
        forceDecision: forceDecision,
      );

      if (v2Response != null) {
        if (!v2Response.success) {
          _lastError = v2Response.message ?? '同步失败';
          _setState(SyncState.failed);
          return false;
        }

        if (forceDecision == SyncForceDecision.useClient &&
            v2Response.decision == SyncDecision.useServer) {
          _lastError = '服务端未接受“覆盖服务端”的请求（可能未升级服务端），已取消导入以保护本地数据。';
          _setState(SyncState.failed);
          return false;
        }

        if (v2Response.decision == SyncDecision.useServer &&
            v2Response.toolsData != null) {
          await _distributeToolsData(v2Response.toolsData!);
        }

        if (forceDecision == SyncForceDecision.useServer &&
            (v2Response.decision != SyncDecision.useServer ||
                v2Response.toolsData == null)) {
          await _clearLocalToolsDataForOverwrite();
        }

        await _configService.updateLastSyncState(
          time: v2Response.serverTime,
          serverRevision: v2Response.serverRevision,
        );
        await _localStateService.setLocalUserId(config.userId);

        _setState(SyncState.success);
        return true;
      }

      final request = SyncRequest(
        userId: config.userId,
        toolsData: toolsData,
        forceDecision: forceDecision,
      );
      final response = await _apiClient.sync(config: config, request: request);

      if (!response.success) {
        _lastError = response.message ?? '同步失败';
        _setState(SyncState.failed);
        return false;
      }

      if (forceDecision == SyncForceDecision.useClient &&
          response.toolsData != null) {
        _lastError = '服务端未接受“覆盖服务端”的请求（可能未升级服务端），已取消导入以保护本地数据。';
        _setState(SyncState.failed);
        return false;
      }

      // v1：服务端若返回 tools_data，则覆盖导入
      if (response.toolsData != null) {
        await _distributeToolsData(response.toolsData!);
      }

      if (forceDecision == SyncForceDecision.useServer &&
          response.toolsData == null) {
        await _clearLocalToolsDataForOverwrite();
      }

      await _configService.updateLastSyncTime(response.serverTime);
      await _localStateService.setLocalUserId(config.userId);

      _setState(SyncState.success);
      return true;
    } catch (e) {
      _lastError ??= _stringifyError(e);
      _setState(SyncState.failed);
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// 覆盖导入一份“服务端快照”（用于同步记录回退/排查）。
  ///
  /// 返回值：
  /// - `null`：全部导入成功
  /// - 非空字符串：存在部分工具导入失败的提示文案
  Future<String?> applyServerSnapshot(
    Map<String, Map<String, dynamic>> toolsData,
  ) async {
    _lastError = null;
    await _distributeToolsData(toolsData);
    notifyListeners();
    return _lastError;
  }

  static String _stringifyError(Object e) {
    final text = e.toString();
    if (text.startsWith('SyncApiException: ')) {
      return text.substring('SyncApiException: '.length);
    }
    if (text.startsWith('Exception: ')) {
      return text.substring('Exception: '.length);
    }
    return text;
  }

  /// 检查网络条件
  Future<bool> _checkNetworkCondition(SyncConfig config) async {
    final error = await SyncNetworkPrecheck.check(
      config: config,
      wifiService: _wifiService,
    );
    if (error != null) {
      _lastError = error;
      return false;
    }
    return true;
  }

  /// 收集所有工具的数据
  Future<Map<String, Map<String, dynamic>>> _collectToolsData() async {
    final result = <String, Map<String, dynamic>>{};
    for (final provider in _toolProviders) {
      try {
        result[provider.toolId] = await provider.exportData();
      } catch (e) {
        debugPrint('工具 ${provider.toolId} 导出数据失败: $e');
      }
    }

    return result;
  }

  /// 分发服务端数据给各工具
  Future<void> _distributeToolsData(
    Map<String, Map<String, dynamic>> toolsData,
  ) async {
    final entries = sortToolEntries(toolsData);
    final providersById = {for (final p in _toolProviders) p.toolId: p};

    for (final entry in entries) {
      final toolId = entry.key;
      final data = entry.value;

      final provider = providersById[toolId];
      if (provider == null) continue;

      try {
        await provider.importData(data);
      } catch (e) {
        debugPrint('工具 $toolId 导入数据失败: $e');
        _lastError ??= '部分工具数据导入失败';
      }
    }
  }

  void _setState(SyncState newState) {
    _state = newState;
    notifyListeners();
  }

  Future<SyncResponseV2?> _trySyncV2({
    required SyncConfig config,
    required Map<String, Map<String, dynamic>> toolsData,
    SyncForceDecision? forceDecision,
  }) async {
    final request = SyncRequestV2(
      userId: config.userId,
      clientTimeMs: DateTime.now().millisecondsSinceEpoch,
      clientState: SyncClientState(
        clientIsEmpty: _isAllToolsEmptyForDecision(toolsData),
        lastServerRevision: config.lastServerRevision,
      ),
      toolsData: toolsData,
      forceDecision: forceDecision,
    );

    try {
      return await _apiClient.syncV2(config: config, request: request);
    } on SyncApiException catch (e) {
      // 服务端未实现 v2：允许回退到 v1
      if (e.statusCode == 404 || e.statusCode == 405) {
        return null;
      }
      rethrow;
    }
  }

  Future<void> _clearLocalToolsDataForOverwrite() async {
    final empty = <String, Map<String, dynamic>>{};

    for (final provider in _toolProviders) {
      // 覆盖本地时不清理 app_config：避免把用户刚保存的配置全部抹掉。
      if (provider.toolId == 'app_config') continue;

      try {
        final exported = await provider.exportData();
        empty[provider.toolId] = _emptySnapshotFromExported(exported);
      } catch (e) {
        debugPrint('工具 ${provider.toolId} 生成空快照失败: $e');
      }
    }

    if (empty.isEmpty) return;
    await _distributeToolsData(empty);
  }

  static Map<String, dynamic> _emptySnapshotFromExported(
    Map<String, dynamic> exported,
  ) {
    final out = <String, dynamic>{};

    final version = exported['version'];
    if (version != null) out['version'] = version;

    final dataRaw = exported['data'];
    if (dataRaw is Map) {
      final cleared = <String, dynamic>{};
      for (final k in dataRaw.keys) {
        cleared[k.toString()] = null;
      }
      out['data'] = cleared;
    } else {
      out['data'] = const <String, dynamic>{};
    }

    return out;
  }

  static bool _isAllToolsEmptyForDecision(
    Map<String, Map<String, dynamic>> toolsData,
  ) {
    final values = toolsData.entries
        .where((e) => e.key != 'app_config')
        .map((e) => e.value)
        .toList(growable: false);
    if (values.isEmpty) return true;
    return values.every(_isToolSnapshotEmpty);
  }

  static bool _isToolSnapshotEmpty(Map<String, dynamic> snapshot) {
    final data = snapshot['data'];
    if (data == null) return false;
    return _isDeepEmpty(data);
  }

  static bool _isDeepEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is bool) return true;
    if (value is num) return true;
    if (value is List) return value.isEmpty;
    if (value is Map) {
      if (value.isEmpty) return true;
      for (final v in value.values) {
        if (!_isDeepEmpty(v)) return false;
      }
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }
}
