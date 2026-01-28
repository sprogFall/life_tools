import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/obj_store/data_capsule/data_capsule_client.dart';
import 'package:http/http.dart' as http;

import '../../test_helpers/recording_http_client.dart';

void main() {
  group('DataCapsuleClient.probePublicUrl', () {
    test('当带 Range 被拒绝时应回退到纯 GET', () async {
      var callCount = 0;
      final client = RecordingHttpClient((request) async {
        callCount++;
        if (callCount == 1) {
          expect(request.method, 'GET');
          expect(request.headers['Range'], 'bytes=0-0');
          return http.StreamedResponse(const Stream<List<int>>.empty(), 403);
        }
        if (callCount == 2) {
          expect(request.method, 'GET');
          expect(request.headers.containsKey('Range'), isFalse);
          return http.StreamedResponse(const Stream<List<int>>.empty(), 200);
        }
        throw StateError('Unexpected callCount: $callCount');
      });

      final ok = await DataCapsuleClient(httpClient: client).probePublicUrl(
        url: 'https://example.com/bkt/media/a.jpg?X-Amz-Signature=abc',
        timeout: const Duration(seconds: 1),
      );
      expect(ok, isTrue);
      expect(callCount, 2);
    });

    test('首次成功时不应重试', () async {
      var callCount = 0;
      final client = RecordingHttpClient((request) async {
        callCount++;
        expect(request.method, 'GET');
        expect(request.headers['Range'], 'bytes=0-0');
        return http.StreamedResponse(const Stream<List<int>>.empty(), 206);
      });

      final ok = await DataCapsuleClient(httpClient: client).probePublicUrl(
        url: 'https://example.com/bkt/media/a.jpg?X-Amz-Signature=abc',
        timeout: const Duration(seconds: 1),
      );
      expect(ok, isTrue);
      expect(callCount, 1);
    });

    test('416（Range 不可满足）也应视为存在', () async {
      final client = RecordingHttpClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['Range'], 'bytes=0-0');
        return http.StreamedResponse(const Stream<List<int>>.empty(), 416);
      });

      final ok = await DataCapsuleClient(httpClient: client).probePublicUrl(
        url: 'https://example.com/bkt/media/empty.jpg?X-Amz-Signature=abc',
        timeout: const Duration(seconds: 1),
      );
      expect(ok, isTrue);
    });
  });

  group('DataCapsuleClient.probePrivateObject', () {
    test('应使用签名 GET + Range，并携带 Authorization 头', () async {
      final client = RecordingHttpClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), contains('/bkt/media/a.jpg'));
        expect(request.headers['Range'], 'bytes=0-0');
        expect(
          request.headers['Authorization'] ?? request.headers['authorization'],
          isNotNull,
        );
        expect(request.headers['x-amz-date'], isNotNull);
        expect(request.headers['x-amz-content-sha256'], isNotNull);
        return http.StreamedResponse(const Stream<List<int>>.empty(), 206);
      });

      final ok =
          await DataCapsuleClient(
            httpClient: client,
            nowUtc: () => DateTime.utc(2020, 1, 1, 0, 0, 0),
          ).probePrivateObject(
            accessKey: 'ak',
            secretKey: 'sk',
            region: 'us-east-1',
            endpoint: 's3.cstcloud.cn',
            bucket: 'bkt',
            key: 'media/a.jpg',
            useHttps: true,
            forcePathStyle: true,
            timeout: const Duration(seconds: 1),
          );
      expect(ok, isTrue);
    });

    test('416 也应视为存在', () async {
      final client = RecordingHttpClient((request) async {
        return http.StreamedResponse(const Stream<List<int>>.empty(), 416);
      });

      final ok = await DataCapsuleClient(httpClient: client).probePrivateObject(
        accessKey: 'ak',
        secretKey: 'sk',
        region: 'us-east-1',
        endpoint: 's3.cstcloud.cn',
        bucket: 'bkt',
        key: 'media/empty.jpg',
        useHttps: true,
        forcePathStyle: true,
        timeout: const Duration(seconds: 1),
      );
      expect(ok, isTrue);
    });
  });
}
