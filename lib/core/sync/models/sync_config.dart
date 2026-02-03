import 'dart:convert';

/// 同步网络类型
enum SyncNetworkType {
  public(0), // 公网模式：直接同步
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
  final String userId; // 用户标识（用于服务端区分用户）
  final SyncNetworkType networkType; // 网络类型
  final String serverUrl; // 服务器地址（不含端口）
  final int serverPort; // 服务器端口
  final Map<String, String> customHeaders; // 自定义请求头（如认证token）
  final List<String> allowedWifiNames; // 私网模式下允许的WiFi名称列表
  final bool autoSyncOnStartup; // 启动时自动同步
  final DateTime? lastSyncTime; // 上次同步时间
  final int? lastServerRevision; // 上次同步后的服务端游标（v2协议）

  const SyncConfig({
    required this.userId,
    required this.networkType,
    required this.serverUrl,
    required this.serverPort,
    required this.customHeaders,
    required this.allowedWifiNames,
    this.autoSyncOnStartup = true,
    this.lastSyncTime,
    this.lastServerRevision,
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
    if (url.isEmpty) return '';

    final hasScheme = url.contains('://');
    final defaultScheme = hasScheme ? null : _inferDefaultScheme(url, serverPort);
    final withScheme = hasScheme ? url : '$defaultScheme://$url';
    final parsed = Uri.tryParse(withScheme);
    if (parsed == null || parsed.host.trim().isEmpty) {
      // 回退：尽力返回旧格式（避免因为解析失败直接崩溃）
      if (hasScheme) return '$url:$serverPort';
      return '${defaultScheme ?? "https"}://$url:$serverPort';
    }

    final scheme = parsed.scheme.trim().isEmpty
        ? (defaultScheme ?? 'https')
        : parsed.scheme;
    final port = parsed.hasPort ? parsed.port : serverPort;
    // 不携带 path/query/fragment，避免生成类似 https://host/path:443 的无效 URL
    final host = parsed.host.contains(':') ? '[${parsed.host}]' : parsed.host;
    return '$scheme://$host:$port';
  }

  static String _inferDefaultScheme(String rawUrl, int serverPort) {
    final probe = Uri.tryParse('http://$rawUrl');
    final host = (probe?.host.trim().isNotEmpty ?? false)
        ? probe!.host.trim()
        : rawUrl.split('/').first.trim();

    final effectivePort = probe?.hasPort == true ? probe!.port : serverPort;

    // 内网/本地默认 http，公网默认 https
    if (_isLocalOrPrivateHost(host)) return 'http';

    // 常见本地部署端口：默认按 http 处理，避免 TLS 握手错误
    if (effectivePort == 80 || effectivePort == 8080) return 'http';

    return 'https';
  }

  static bool _isLocalOrPrivateHost(String host) {
    final lower = host.toLowerCase();
    if (lower == 'localhost' || lower == '127.0.0.1' || lower == '::1') {
      return true;
    }

    final parts = lower.split('.');
    if (parts.length == 4) {
      final a = int.tryParse(parts[0]);
      final b = int.tryParse(parts[1]);
      if (a == null || b == null) return false;

      if (a == 10) return true;
      if (a == 192 && b == 168) return true;
      if (a == 172 && b >= 16 && b <= 31) return true;
    }

    return false;
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
    'lastServerRevision': lastServerRevision,
  };

  static int _readInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? fallback;
    return fallback;
  }

  static bool _readBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is String) {
      final v = value.trim().toLowerCase();
      if (v == 'true') return true;
      if (v == 'false') return false;
    }
    return fallback;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is List) return value.whereType<String>().toList();
    return const <String>[];
  }

  static Map<String, String> _readStringMap(dynamic value) {
    if (value is! Map) return const <String, String>{};
    final result = <String, String>{};
    for (final entry in value.entries) {
      final key = entry.key;
      final val = entry.value;
      if (key is String && val is String) {
        result[key] = val;
      }
    }
    return result;
  }

  static SyncConfig fromMap(Map<String, dynamic> map) {
    return SyncConfig(
      userId: (map['userId'] as String?) ?? '',
      networkType: SyncNetworkType.fromValue(
        _readInt(map['networkType'], fallback: 0),
      ),
      serverUrl: (map['serverUrl'] as String?) ?? '',
      serverPort: _readInt(map['serverPort'], fallback: 443),
      customHeaders: _readStringMap(map['customHeaders']),
      allowedWifiNames: _readStringList(map['allowedWifiNames']),
      autoSyncOnStartup: _readBool(map['autoSyncOnStartup'], fallback: true),
      lastSyncTime: map['lastSyncTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              _readInt(map['lastSyncTime'], fallback: 0),
            )
          : null,
      lastServerRevision: map['lastServerRevision'] == null
          ? null
          : _readInt(map['lastServerRevision'], fallback: 0),
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
    int? lastServerRevision,
    bool clearLastSyncTime = false,
    bool clearLastServerRevision = false,
  }) {
    return SyncConfig(
      userId: userId ?? this.userId,
      networkType: networkType ?? this.networkType,
      serverUrl: serverUrl ?? this.serverUrl,
      serverPort: serverPort ?? this.serverPort,
      customHeaders: customHeaders ?? this.customHeaders,
      allowedWifiNames: allowedWifiNames ?? this.allowedWifiNames,
      autoSyncOnStartup: autoSyncOnStartup ?? this.autoSyncOnStartup,
      lastSyncTime: clearLastSyncTime
          ? null
          : (lastSyncTime ?? this.lastSyncTime),
      lastServerRevision: clearLastServerRevision
          ? null
          : (lastServerRevision ?? this.lastServerRevision),
    );
  }
}
