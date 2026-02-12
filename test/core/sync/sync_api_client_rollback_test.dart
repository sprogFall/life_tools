import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:life_tools/core/sync/models/sync_config.dart';
import 'package:life_tools/core/sync/services/sync_api_client.dart';

import '../../test_helpers/recording_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncApiClient rollback/snapshots', () {
    const config = SyncConfig(
      userId: 'u1',
      networkType: SyncNetworkType.public,
      serverUrl: '127.0.0.1',
      serverPort: 8080,
      customHeaders: {},
      allowedWifiNames: [],
      autoSyncOnStartup: false,
    );

    test('getSnapshotByRevision 应正确拼接 URL 并解析响应', () async {
      final client = RecordingHttpClient((request) async {
        final body = jsonEncode({
          'success': true,
          'snapshot': {
            'user_id': 'u1',
            'server_revision': 12,
            'updated_at_ms': 1234,
            'tools_data': {
              'work_log': {
                'version': 1,
                'data': {'tasks': []},
              },
            },
          },
        });
        return http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final api = SyncApiClient(httpClient: client);
      final snapshot = await api.getSnapshotByRevision(
        config: config,
        revision: 12,
      );

      expect(
        client.lastRequest?.url.toString(),
        'http://127.0.0.1:8080/sync/snapshots/12?user_id=u1',
      );
      expect(snapshot.serverRevision, 12);
      expect(snapshot.updatedAtMs, 1234);
      expect(snapshot.toolsData.containsKey('work_log'), true);
    });

    test('rollbackToRevision 应正确拼接 URL/请求体 并解析响应', () async {
      final client = RecordingHttpClient((request) async {
        final body = jsonEncode({
          'success': true,
          'server_time': 2000,
          'server_revision': 3,
          'restored_from_revision': 1,
          'tools_data': {
            'work_log': {
              'version': 1,
              'data': {'tasks': []},
            },
          },
        });
        return http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final api = SyncApiClient(httpClient: client);
      final result = await api.rollbackToRevision(
        config: config,
        targetRevision: 1,
      );

      expect(
        client.lastRequest?.url.toString(),
        'http://127.0.0.1:8080/sync/rollback',
      );
      final req = client.lastRequest as http.Request;
      expect(req.body, contains('"user_id":"u1"'));
      expect(req.body, contains('"target_revision":1'));
      expect(result.serverRevision, 3);
      expect(result.restoredFromRevision, 1);
    });

    test('TLS/握手错误应返回更友好的提示', () async {
      final client = RecordingHttpClient((request) async {
        throw Exception(
          'HandshakeException: Handshake error in client (OS Error: WRONG_VERSION_NUMBER)',
        );
      });
      final api = SyncApiClient(httpClient: client);
      try {
        await api.rollbackToRevision(config: config, targetRevision: 1);
        fail('should throw');
      } catch (e) {
        expect(e, isA<SyncApiException>());
        expect(e.toString(), contains('TLS/HTTPS'));
        expect(e.toString(), contains('http://127.0.0.1:8080'));
      }
    });
  });
}
