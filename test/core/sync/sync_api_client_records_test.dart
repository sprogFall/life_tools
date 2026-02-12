import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:life_tools/core/sync/models/sync_config.dart';
import 'package:life_tools/core/sync/services/sync_api_client.dart';

import '../../test_helpers/recording_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncApiClient records', () {
    const config = SyncConfig(
      userId: 'u1',
      networkType: SyncNetworkType.public,
      serverUrl: 'http://127.0.0.1',
      serverPort: 8080,
      customHeaders: {},
      allowedWifiNames: [],
      autoSyncOnStartup: false,
    );

    test('listSyncRecords 应正确拼接 URL 并解析响应', () async {
      final client = RecordingHttpClient((request) async {
        final body = jsonEncode({
          'success': true,
          'records': [
            {
              'id': 12,
              'user_id': 'u1',
              'protocol_version': 2,
              'decision': 'use_client',
              'server_time': 1000,
              'client_time': 900,
              'client_updated_at_ms': 200,
              'server_updated_at_ms_before': 0,
              'server_updated_at_ms_after': 200,
              'server_revision_before': 0,
              'server_revision_after': 1,
              'diff_summary': {'changed_tools': 1, 'diff_items': 3},
            },
          ],
          'next_before_id': 12,
        });
        return http.StreamedResponse(
          Stream.value(utf8.encode(body)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final api = SyncApiClient(httpClient: client);
      final result = await api.listSyncRecords(
        config: config,
        limit: 50,
        beforeId: 99,
      );

      expect(
        client.lastRequest?.url.toString(),
        'http://127.0.0.1:8080/sync/records?user_id=u1&limit=50&before_id=99',
      );
      expect(result.records.length, 1);
      expect(result.records.first.id, 12);
      expect(result.nextBeforeId, 12);
    });

    test('getSyncRecord 应正确拼接 URL 并解析响应', () async {
      final client = RecordingHttpClient((request) async {
        final body = jsonEncode({
          'success': true,
          'record': {
            'id': 12,
            'user_id': 'u1',
            'protocol_version': 2,
            'decision': 'use_server',
            'server_time': 1000,
            'client_time': 900,
            'client_updated_at_ms': 100,
            'server_updated_at_ms_before': 200,
            'server_updated_at_ms_after': 200,
            'server_revision_before': 1,
            'server_revision_after': 1,
            'diff_summary': {'changed_tools': 1, 'diff_items': 3},
            'diff': {
              'summary': {'changed_tools': 1, 'diff_items': 3},
              'tools': {
                'work_log': {'same': false, 'diff_items': []},
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
      final record = await api.getSyncRecord(config: config, id: 12);

      expect(
        client.lastRequest?.url.toString(),
        'http://127.0.0.1:8080/sync/records/12?user_id=u1',
      );
      expect(record.id, 12);
    });
  });
}
