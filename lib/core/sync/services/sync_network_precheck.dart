import '../models/sync_config.dart';
import 'wifi_service.dart';

class SyncNetworkPrecheck {
  const SyncNetworkPrecheck._();

  static const String privateWifiMustConnectWifiPrefix =
      '网络预检失败：私网模式下必须连接 WiFi';

  static bool isPrivateWifiNotConnectedError(String? error) {
    if (error == null) return false;
    return error.startsWith(privateWifiMustConnectWifiPrefix);
  }

  /// 返回 null 表示网络条件满足；否则返回可直接展示给用户的错误文案。
  static Future<String?> check({
    required SyncConfig config,
    required WifiService wifiService,
  }) async {
    final networkStatus = await wifiService.getNetworkStatus();

    if (networkStatus == NetworkStatus.offline) {
      return '网络预检失败：当前无网络连接';
    }

    // 公网模式：只要不是离线即可
    if (config.networkType == SyncNetworkType.public) {
      return null;
    }

    // 私网模式：必须是 WiFi 且在允许列表中
    if (networkStatus != NetworkStatus.wifi) {
      return '$privateWifiMustConnectWifiPrefix（当前：${networkStatus.name}）';
    }

    final allowed = config.allowedWifiNames
        .map(WifiService.normalizeWifiName)
        .whereType<String>()
        .toSet();

    if (allowed.isEmpty) {
      return '网络预检失败：私网模式未配置允许的 WiFi 列表';
    }

    final rawSsid = await wifiService.getCurrentWifiName();
    final currentSsid = WifiService.normalizeWifiName(rawSsid);

    if (currentSsid == null) {
      return [
        '网络预检失败：已连接 WiFi，但无法获取当前 WiFi 名称（SSID）',
        '可能原因：未授予定位权限 / 未开启定位 / 系统限制（返回 <unknown ssid>）',
        '调试信息：networkStatus=wifi, rawSsid=${rawSsid ?? "null"}, allowed=${allowed.join("，")}',
      ].join('\n');
    }

    if (!allowed.contains(currentSsid)) {
      return [
        '网络预检失败：当前 WiFi（$currentSsid）不在允许列表中：${allowed.join("，")}',
        '调试信息：rawSsid=${rawSsid ?? "null"}（注意是否包含引号/空格）',
      ].join('\n');
    }

    return null;
  }
}
