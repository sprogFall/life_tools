import 'package:flutter/foundation.dart';
import '../../registry/tool_registry.dart';
import '../models/sync_config.dart';
import '../models/sync_request.dart';
import 'sync_api_client.dart';
import 'sync_config_service.dart';
import 'wifi_service.dart';

/// 同步状态
enum SyncState {
  idle,       // 空闲
  checking,   // 检查条件
  syncing,    // 同步中
  success,    // 同步成功
  failed,     // 同步失败
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
  })  : _configService = configService,
        _wifiService = wifiService ?? WifiService(),
        _apiClient = apiClient ?? SyncApiClient();

  /// 执行同步（主入口）
  Future<bool> sync() async {
    // 加锁，防止并发同步
    if (_isSyncing) {
      _lastError = '同步正在进行中，请稍候';
      return false;
    }

    _isSyncing = true;
    _setState(SyncState.checking);
    _lastError = null;

    try {
      // 1. 检查配置
      final config = _configService.config;
      if (config == null || !config.isValid) {
        throw Exception('同步配置未设置或不完整');
      }

      // 2. 检查网络条件
      final canSync = await _checkNetworkCondition(config);
      if (!canSync) {
        throw Exception('当前网络条件不满足同步要求');
      }

      // 3. 收集工具数据
      _setState(SyncState.syncing);
      final toolsData = await _collectToolsData();

      if (toolsData.isEmpty) {
        // 没有工具支持同步，直接返回成功
        _setState(SyncState.success);
        await _configService.updateLastSyncTime(DateTime.now());
        return true;
      }

      // 4. 调用同步API
      final request = SyncRequest(
        userId: config.userId,
        toolsData: toolsData,
      );

      final response = await _apiClient.sync(
        config: config,
        request: request,
      );

      if (!response.success) {
        throw Exception(response.message ?? '同步失败');
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
      _lastError = e.toString();
      _setState(SyncState.failed);
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// 检查网络条件
  Future<bool> _checkNetworkCondition(SyncConfig config) async {
    final networkStatus = await _wifiService.getNetworkStatus();

    // 离线直接失败
    if (networkStatus == NetworkStatus.offline) {
      _lastError = '当前无网络连接';
      return false;
    }

    // 公网模式：任何网络都可以
    if (config.networkType == SyncNetworkType.public) {
      return true;
    }

    // 私网模式：必须是WiFi且在允许列表中
    if (networkStatus != NetworkStatus.wifi) {
      _lastError = '私网模式下必须连接WiFi';
      return false;
    }

    final isAllowed = await _wifiService.isWifiAllowed(config.allowedWifiNames);
    if (!isAllowed) {
      final currentWifi = await _wifiService.getCurrentWifiName();
      _lastError = '当前WiFi（${currentWifi ?? "未知"}）不在允许列表中';
      return false;
    }

    return true;
  }

  /// 收集所有工具的数据
  Future<Map<String, Map<String, dynamic>>> _collectToolsData() async {
    final result = <String, Map<String, dynamic>>{};
    final tools = ToolRegistry.instance.tools;

    for (final tool in tools) {
      if (tool.supportSync) {
        try {
          final data = await tool.syncProvider!.exportData();
          result[tool.id] = data;
        } catch (e) {
          debugPrint('工具 ${tool.name} 导出数据失败: $e');
          // 单个工具失败不影响其他工具
        }
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
      if (tool != null && tool.supportSync) {
        try {
          await tool.syncProvider!.importData(data);
        } catch (e) {
          debugPrint('工具 ${tool.name} 导入数据失败: $e');
          // 单个工具导入失败不影响其他工具
          // 但应该记录到lastError中
          if (_lastError == null) {
            _lastError = '部分工具数据导入失败';
          }
        }
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
