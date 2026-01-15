import 'package:flutter/foundation.dart';

import '../../registry/tool_registry.dart';
import '../models/sync_config.dart';
import '../models/sync_request.dart';
import 'sync_api_client.dart';
import 'sync_config_service.dart';
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
  }) : _configService = configService,
       _wifiService = wifiService ?? WifiService(),
       _apiClient = apiClient ?? SyncApiClient();

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

      // 4. 调用同步 API
      final request = SyncRequest(userId: config.userId, toolsData: toolsData);

      final response = await _apiClient.sync(config: config, request: request);

      if (!response.success) {
        _lastError = response.message ?? '同步失败';
        _setState(SyncState.failed);
        return false;
      }

      // 5. 分发服务端数据给各工具
      if (response.toolsData != null) {
        await _distributeToolsData(response.toolsData!);
      }

      // 6. 更新同步时间
      await _configService.updateLastSyncTime(response.serverTime);

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
    final networkStatus = await _wifiService.getNetworkStatus();

    if (networkStatus == NetworkStatus.offline) {
      _lastError = '网络预检失败：当前无网络连接';
      return false;
    }

    // 公网模式：只要不是离线即可
    if (config.networkType == SyncNetworkType.public) {
      return true;
    }

    // 私网模式：必须是 WiFi 且在允许列表中
    if (networkStatus != NetworkStatus.wifi) {
      _lastError = '网络预检失败：私网模式下必须连接 WiFi（当前：${networkStatus.name}）';
      return false;
    }

    final allowed = config.allowedWifiNames
        .map(WifiService.normalizeWifiName)
        .whereType<String>()
        .toSet();

    if (allowed.isEmpty) {
      _lastError = '网络预检失败：私网模式未配置允许的 WiFi 列表';
      return false;
    }

    final rawSsid = await _wifiService.getCurrentWifiName();
    final currentSsid = WifiService.normalizeWifiName(rawSsid);

    if (currentSsid == null) {
      _lastError = [
        '网络预检失败：已连接 WiFi，但无法获取当前 WiFi 名称（SSID）',
        '可能原因：未授予定位权限 / 未开启定位 / 系统限制（返回 <unknown ssid>）',
        '调试信息：networkStatus=wifi, rawSsid=${rawSsid ?? "null"}, allowed=${allowed.join("，")}',
      ].join('\n');
      return false;
    }

    if (!allowed.contains(currentSsid)) {
      _lastError = [
        '网络预检失败：当前 WiFi（$currentSsid）不在允许列表中：${allowed.join("，")}',
        '调试信息：rawSsid=${rawSsid ?? "null"}（注意是否包含引号/空格）',
      ].join('\n');
      return false;
    }

    return true;
  }

  /// 收集所有工具的数据
  Future<Map<String, Map<String, dynamic>>> _collectToolsData() async {
    final result = <String, Map<String, dynamic>>{};
    final tools = ToolRegistry.instance.tools;

    for (final tool in tools) {
      if (!tool.supportSync) continue;
      try {
        result[tool.id] = await tool.syncProvider!.exportData();
      } catch (e) {
        debugPrint('工具 ${tool.name} 导出数据失败: $e');
      }
    }

    return result;
  }

  /// 分发服务端数据给各工具
  Future<void> _distributeToolsData(
    Map<String, Map<String, dynamic>> toolsData,
  ) async {
    final tools = ToolRegistry.instance.tools;

    for (final entry in toolsData.entries) {
      final toolId = entry.key;
      final data = entry.value;

      final tool = tools.where((t) => t.id == toolId).firstOrNull;
      if (tool == null || !tool.supportSync) continue;

      try {
        await tool.syncProvider!.importData(data);
      } catch (e) {
        debugPrint('工具 ${tool.name} 导入数据失败: $e');
        _lastError ??= '部分工具数据导入失败';
      }
    }
  }

  void _setState(SyncState newState) {
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }
}
