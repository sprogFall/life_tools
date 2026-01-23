import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_tools/tools/overcooked_kitchen/services/overcooked_image_cache_service.dart';

void main() {
  group('OvercookedImageCacheService', () {
    test('缓存未命中时应下载并写入缓存文件', () async {
      final temp = await Directory.systemTemp.createTemp();
      addTearDown(() async => temp.delete(recursive: true));

      final service = OvercookedImageCacheService(
        baseDirProvider: () async => temp,
        httpClient: MockClient((req) async {
          return http.Response.bytes(
            Uint8List.fromList([1, 2, 3, 4]),
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );

      final f = await service.ensureCached(
        key: 'media/a.png',
        resolveUri: () async => 'https://example.com/a.png',
      );
      expect(f, isNotNull);
      expect(f!.existsSync(), isTrue);
      expect(f.readAsBytesSync(), Uint8List.fromList([1, 2, 3, 4]));
    });

    test('已有缓存时不应重复下载', () async {
      final temp = await Directory.systemTemp.createTemp();
      addTearDown(() async => temp.delete(recursive: true));

      var calls = 0;
      final service = OvercookedImageCacheService(
        baseDirProvider: () async => temp,
        httpClient: MockClient((req) async {
          calls++;
          return http.Response.bytes(
            Uint8List.fromList([9]),
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }),
      );

      final f1 = await service.ensureCached(
        key: 'media/b.jpg',
        resolveUri: () async => 'https://example.com/b.jpg',
      );
      final f2 = await service.ensureCached(
        key: 'media/b.jpg',
        resolveUri: () async => 'https://example.com/b.jpg',
      );

      expect(calls, 1);
      expect(f1!.path, f2!.path);
    });

    test('并发 ensureCached 同一 key 时只应下载一次', () async {
      final temp = await Directory.systemTemp.createTemp();
      addTearDown(() async => temp.delete(recursive: true));

      var calls = 0;
      final service = OvercookedImageCacheService(
        baseDirProvider: () async => temp,
        httpClient: MockClient((req) async {
          calls++;
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return http.Response.bytes(
            Uint8List.fromList([7, 7]),
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );

      final futures = [
        service.ensureCached(
          key: 'media/c.png',
          resolveUri: () async => 'https://example.com/c.png',
        ),
        service.ensureCached(
          key: 'media/c.png',
          resolveUri: () async => 'https://example.com/c.png',
        ),
      ];
      final results = await Future.wait(futures);
      expect(calls, 1);
      expect(results[0]!.path, results[1]!.path);
    });
  });
}

