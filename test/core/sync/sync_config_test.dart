import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/sync/models/sync_config.dart';

void main() {
  group('SyncConfig.fullServerUrl', () {
    test('无 scheme 时默认使用 https，并拼接端口', () {
      const cfg = SyncConfig(
        userId: 'u1',
        networkType: SyncNetworkType.public,
        serverUrl: 'sync.example.com',
        serverPort: 443,
        customHeaders: {},
        allowedWifiNames: [],
        autoSyncOnStartup: false,
      );
      expect(cfg.fullServerUrl, 'https://sync.example.com:443');
    });

    test('本地/内网地址无 scheme 时默认使用 http，避免 TLS 握手错误', () {
      const cfg = SyncConfig(
        userId: 'u1',
        networkType: SyncNetworkType.public,
        serverUrl: '127.0.0.1',
        serverPort: 8080,
        customHeaders: {},
        allowedWifiNames: [],
        autoSyncOnStartup: false,
      );
      expect(cfg.fullServerUrl, 'http://127.0.0.1:8080');
    });

    test('有 scheme 时保留 scheme，并拼接端口（忽略 path）', () {
      const cfg = SyncConfig(
        userId: 'u1',
        networkType: SyncNetworkType.public,
        serverUrl: 'http://sync.example.com/api',
        serverPort: 8080,
        customHeaders: {},
        allowedWifiNames: [],
        autoSyncOnStartup: false,
      );
      expect(cfg.fullServerUrl, 'http://sync.example.com:8080');
    });

    test('serverUrl 自带端口时不应生成重复端口', () {
      const cfg = SyncConfig(
        userId: 'u1',
        networkType: SyncNetworkType.public,
        serverUrl: 'https://sync.example.com:8443',
        serverPort: 443,
        customHeaders: {},
        allowedWifiNames: [],
        autoSyncOnStartup: false,
      );
      expect(cfg.fullServerUrl, 'https://sync.example.com:8443');
    });
  });
}
