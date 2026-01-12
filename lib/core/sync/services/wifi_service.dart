import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// 网络状态
enum NetworkStatus {
  wifi,
  mobile,
  offline,
  unknown,
}

/// WiFi 检测服务
class WifiService {
  final Connectivity _connectivity;
  final NetworkInfo _networkInfo;

  WifiService({
    Connectivity? connectivity,
    NetworkInfo? networkInfo,
  })  : _connectivity = connectivity ?? Connectivity(),
        _networkInfo = networkInfo ?? NetworkInfo();

  /// 获取当前网络状态
  Future<NetworkStatus> getNetworkStatus() async {
    final result = await _connectivity.checkConnectivity();

    // connectivity_plus 6.x 返回 List<ConnectivityResult>
    if (result.contains(ConnectivityResult.wifi)) {
      return NetworkStatus.wifi;
    } else if (result.contains(ConnectivityResult.mobile)) {
      return NetworkStatus.mobile;
    } else if (result.contains(ConnectivityResult.none)) {
      return NetworkStatus.offline;
    }
    return NetworkStatus.unknown;
  }

  /// 获取当前连接的 WiFi 名称（SSID）
  ///
  /// 注意：
  /// - Android 需要定位权限（ACCESS_FINE_LOCATION），且通常需要开启定位
  /// - iOS 需要 “Access WiFi Information” 权限
  /// - 失败时返回 null
  Future<String?> getCurrentWifiName() async {
    try {
      return normalizeWifiName(await _networkInfo.getWifiName());
    } catch (_) {
      return null;
    }
  }

  /// 对 WiFi 名称做基础归一化（去引号/trim/过滤未知 SSID）
  static String? normalizeWifiName(String? wifiName) {
    if (wifiName == null) return null;

    final normalized = wifiName.replaceAll('"', '').trim();
    if (normalized.isEmpty) return null;

    final lower = normalized.toLowerCase();
    if (lower == '<unknown ssid>' || lower == 'unknown ssid') return null;

    return normalized;
  }

  /// 检查当前 WiFi 是否在允许列表中
  Future<bool> isWifiAllowed(List<String> allowedWifiNames) async {
    if (allowedWifiNames.isEmpty) return false;

    final status = await getNetworkStatus();
    if (status != NetworkStatus.wifi) return false;

    final currentWifi = normalizeWifiName(await getCurrentWifiName());
    if (currentWifi == null) return false;

    final normalizedAllowed = allowedWifiNames
        .map(normalizeWifiName)
        .whereType<String>()
        .toSet();
    return normalizedAllowed.contains(currentWifi);
  }
}

