import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:life_tools/tools/overcooked_kitchen/services/overcooked_image_cache_service.dart';

class _CountHttpClient extends http.BaseClient {
  int count = 0;
  final Uint8List body;

  _CountHttpClient({required this.body});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    count++;
    return http.StreamedResponse(
      Stream<List<int>>.value(body),
      200,
      headers: const {'content-type': 'image/png'},
    );
  }
}

void main() {
  group('OvercookedImageCacheService', () {
    test('ensureCached 命中缓存时不应重复下载', () async {
      final tmp = await Directory.systemTemp.createTemp('life_tools_test_');
      addTearDown(() async {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      });

      final client = _CountHttpClient(body: Uint8List.fromList([1, 2, 3]));
      final cache = OvercookedImageCacheService(
        baseDirProvider: () async => tmp,
        httpClient: client,
      );

      final key = 'media/a.png';
      final f1 = await cache.ensureCached(
        key: key,
        resolveUri: () async => 'https://example.com/a.png',
      );
      expect(f1, isNotNull);
      expect(
        File('${tmp.path}/overcooked_image_cache/.nomedia').existsSync(),
        isTrue,
      );
      expect(client.count, 1);

      final f2 = await cache.ensureCached(
        key: key,
        resolveUri: () async => 'https://example.com/a.png',
      );
      expect(f2?.path, f1?.path);
      expect(client.count, 1);
    });
  });
}
