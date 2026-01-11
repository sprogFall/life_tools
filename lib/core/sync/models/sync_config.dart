import 'dart:convert';

/// 同步网络类型
enum SyncNetworkType {
  public(0),      // 公网模式：直接同步
  privateWifi(1); // 私网模式：需要匹配WiFi名称

  final int value;
  const SyncNetworkType(this.value);

  static SyncNetworkType fromValue(int value) {
    return SyncNetworkType.values.firstWhere(
      (t) => t.value == value,
      orElse: () => SyncNetworkType.public,
    );
  }
}

/// 同步配置模型
class SyncConfig {
  final String userId;              // 用户标识（用于服务端区分用户）
  final SyncNetworkType networkType; // 网络类型
  final String serverUrl;           // 服务器地址（不含端口）
  final int serverPort;             // 服务器端口
  final Map<String, String> customHeaders; // 自定义请求头（如认证token）
  final List<String> allowedWifiNames; // 私网模式下允许的WiFi名称列表
  final bool autoSyncOnStartup;     // 启动时自动同步
  final DateTime? lastSyncTime;     // 上次同步时间

  const SyncConfig({
    required this.userId,
    required this.networkType,
    required this.serverUrl,
    required this.serverPort,
    required this.customHeaders,
    required this.allowedWifiNames,
    this.autoSyncOnStartup = true,
    this.lastSyncTime,
  });

  /// 验证配置是否有效
  bool get isValid =>
      userId.trim().isNotEmpty &&
      serverUrl.trim().isNotEmpty &&
      serverPort > 0 &&
      serverPort < 65536 &&
      (networkType == SyncNetworkType.public || allowedWifiNames.isNotEmpty);

  /// 构建完整的服务端URL
  String get fullServerUrl {
    final url = serverUrl.trim();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return '$url:$serverPort';
    }
    return 'https://$url:$serverPort';
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'networkType': networkType.value,
        'serverUrl': serverUrl,
        'serverPort': serverPort,
        'customHeaders': customHeaders,
        'allowedWifiNames': allowedWifiNames,
        'autoSyncOnStartup': autoSyncOnStartup,
        'lastSyncTime': lastSyncTime?.millisecondsSinceEpoch,
      };

  static SyncConfig fromMap(Map<String, dynamic> map) {
    return SyncConfig(
      userId: (map['userId'] as String?) ?? '',
      networkType: SyncNetworkType.fromValue((map['networkType'] as int?) ?? 0),
      serverUrl: (map['serverUrl'] as String?) ?? '',
      serverPort: (map['serverPort'] as int?) ?? 443,
      customHeaders: Map<String, String>.from(
        (map['customHeaders'] as Map<String, dynamic>?) ?? {},
      ),
      allowedWifiNames: List<String>.from(
        (map['allowedWifiNames'] as List<dynamic>?) ?? [],
      ),
      autoSyncOnStartup: (map['autoSyncOnStartup'] as bool?) ?? true,
      lastSyncTime: map['lastSyncTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSyncTime'] as int)
          : null,
    );
  }

  String toJsonString() => jsonEncode(toMap());

  static SyncConfig? tryFromJsonString(String? json) {
    if (json == null || json.trim().isEmpty) return null;
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      return fromMap(map);
    } catch (_) {
      return null;
    }
  }

  SyncConfig copyWith({
    String? userId,
    SyncNetworkType? networkType,
    String? serverUrl,
    int? serverPort,
    Map<String, String>? customHeaders,
    List<String>? allowedWifiNames,
    bool? autoSyncOnStartup,
    DateTime? lastSyncTime,
    bool clearLastSyncTime = false,
  }) {
    return SyncConfig(
      userId: userId ?? this.userId,
      networkType: networkType ?? this.networkType,
      serverUrl: serverUrl ?? this.serverUrl,
      serverPort: serverPort ?? this.serverPort,
      customHeaders: customHeaders ?? this.customHeaders,
      allowedWifiNames: allowedWifiNames ?? this.allowedWifiNames,
      autoSyncOnStartup: autoSyncOnStartup ?? this.autoSyncOnStartup,
      lastSyncTime: clearLastSyncTime ? null : (lastSyncTime ?? this.lastSyncTime),
    );
  }
}
