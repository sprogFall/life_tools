import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// 网络状态
enum NetworkStatus {
  wifi,
  mobile,
  offline,
  unknown,
}

/// WiFi检测服务
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

  /// 获取当前连接的WiFi名称（SSID）
  ///
  /// 注意：
  /// - Android 需要位置权限（ACCESS_FINE_LOCATION）
  /// - iOS 需要"Access WiFi Information"权限
  /// - 失败时返回 null
  Future<String?> getCurrentWifiName() async {
    try {
      final wifiName = await _networkInfo.getWifiName();
      // 移除可能的引号（iOS会返回带引号的SSID）
      if (wifiName != null) {
        return wifiName.replaceAll('"', '');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 检查当前WiFi是否在允许列表中
  Future<bool> isWifiAllowed(List<String> allowedWifiNames) async {
    if (allowedWifiNames.isEmpty) return false;

    final status = await getNetworkStatus();
    if (status != NetworkStatus.wifi) return false;

    final currentWifi = await getCurrentWifiName();
    if (currentWifi == null) return false;

    return allowedWifiNames.contains(currentWifi);
  }
}
