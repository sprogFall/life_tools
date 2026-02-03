import 'package:flutter/foundation.dart';

import '../../registry/tool_registry.dart';
import '../interfaces/tool_sync_provider.dart';
import '../models/sync_config.dart';
import '../models/sync_request.dart';
import '../models/sync_request_v2.dart';
import '../models/sync_response_v2.dart';
import 'sync_api_client.dart';
import 'sync_config_service.dart';
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

/// 同步核心服务
class SyncService extends ChangeNotifier {
  final SyncConfigService _configService;
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
    WifiService? wifiService,
    SyncApiClient? apiClient,
    Iterable<ToolSyncProvider>? toolProviders,
  }) : _configService = configService,
       _wifiService = wifiService ?? WifiService(),
       _apiClient = apiClient ?? SyncApiClient(),
       _toolProviders = List<ToolSyncProvider>.unmodifiable(
         toolProviders ??
             ToolRegistry.instance.tools
                 .where((t) => t.supportSync)
                 .map((t) => t.syncProvider!),
       );

  /// 执行同步（主入口）
  Future<bool> sync() async {
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

      // 2. 检查网络条件
      if (!await _checkNetworkCondition(config)) {
        _setState(SyncState.failed);
        return false;
      }

      // 3. 收集工具数据
      _setState(SyncState.syncing);
      final toolsData = await _collectToolsData();

      if (toolsData.isEmpty) {
        // 没有工具支持同步：视为成功
        _setState(SyncState.success);
        await _configService.updateLastSyncTime(DateTime.now());
        return true;
      }

      // 4. 调用同步 API（优先 v2，服务端不支持则回退 v1）
      final v2Result = await _trySyncV2(config: config, toolsData: toolsData);
      if (v2Result == _SyncV2Result.failed) {
        return false;
      }
      if (v2Result == _SyncV2Result.notSupported) {
        final request = SyncRequest(
          userId: config.userId,
          toolsData: toolsData,
        );
        final response = await _apiClient.sync(
          config: config,
          request: request,
        );

        if (!response.success) {
          _lastError = response.message ?? '同步失败';
          _setState(SyncState.failed);
          return false;
        }

        // v1：服务端若返回 tools_data，则覆盖导入
        if (response.toolsData != null) {
          await _distributeToolsData(response.toolsData!);
        }

        await _configService.updateLastSyncTime(response.serverTime);
      }

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

  static String _stringifyError(Object e) {
    final text = e.toString();
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

  Future<_SyncV2Result> _trySyncV2({
    required SyncConfig config,
    required Map<String, Map<String, dynamic>> toolsData,
  }) async {
    final request = SyncRequestV2(
      userId: config.userId,
      clientTimeMs: DateTime.now().millisecondsSinceEpoch,
      clientState: SyncClientState(
        clientIsEmpty: _isAllToolsEmpty(toolsData),
        lastServerRevision: config.lastServerRevision,
      ),
      toolsData: toolsData,
    );

    SyncResponseV2 response;
    try {
      response = await _apiClient.syncV2(config: config, request: request);
    } on SyncApiException catch (e) {
      // 服务端未实现 v2：允许回退到 v1
      if (e.statusCode == 404 || e.statusCode == 405) {
        return _SyncV2Result.notSupported;
      }
      rethrow;
    }

    if (!response.success) {
      _lastError = response.message ?? '同步失败';
      _setState(SyncState.failed);
      return _SyncV2Result.failed;
    }

    if (response.decision == SyncDecision.useServer &&
        response.toolsData != null) {
      await _distributeToolsData(response.toolsData!);
    }

    await _configService.updateLastSyncState(
      time: response.serverTime,
      serverRevision: response.serverRevision,
    );

    return _SyncV2Result.success;
  }

  static bool _isAllToolsEmpty(Map<String, Map<String, dynamic>> toolsData) {
    if (toolsData.isEmpty) return true;
    return toolsData.values.every(_isToolSnapshotEmpty);
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

enum _SyncV2Result { notSupported, success, failed }
