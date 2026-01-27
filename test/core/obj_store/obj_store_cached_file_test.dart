import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:life_tools/core/obj_store/obj_store_config.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/obj_store_service.dart';
import 'package:life_tools/core/obj_store/obj_store_secrets.dart';
import 'package:life_tools/core/obj_store/qiniu/qiniu_auth.dart';
import 'package:life_tools/core/obj_store/qiniu/qiniu_client.dart';
import 'package:life_tools/core/obj_store/secret_store/in_memory_secret_store.dart';
import 'package:life_tools/core/obj_store/storage/local_obj_store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class _CountingHttpClient extends http.BaseClient {
  int getCount = 0;
  final Uint8List body;

  _CountingHttpClient({required this.body});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'GET') getCount++;
    return http.StreamedResponse(Stream.value(body), 200);
  }
}

void main() {
  group('ObjStoreService（缓存图片）', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('getCachedFile：未配置时也可命中本地存储文件（key -> baseDir/key）', () async {
      final baseDir = await Directory.systemTemp.createTemp('life_tools_test_');
      addTearDown(() async {
        try {
          await baseDir.delete(recursive: true);
        } catch (_) {}
      });

      final localFile = File('${baseDir.path}/media/a.png');
      await localFile.create(recursive: true);
      await localFile.writeAsBytes([1, 2, 3], flush: true);

      final configService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await configService.init();

      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(baseDirProvider: () async => baseDir),
        qiniuClient: QiniuClient(),
        cacheBaseDirProvider: () async => baseDir,
      );

      final cached = await service.getCachedFile(key: 'media/a.png');
      expect(cached, isNotNull);
      expect(p.normalize(cached!.path), p.normalize(localFile.path));
    });

    test('getCachedFile：不应允许通过 ../ 命中 baseDir 之外的文件', () async {
      final root = await Directory.systemTemp.createTemp('life_tools_test_');
      addTearDown(() async {
        try {
          await root.delete(recursive: true);
        } catch (_) {}
      });

      final baseDir = Directory('${root.path}/base')..createSync();
      final outside = File('${root.path}/secret.txt')
        ..writeAsStringSync('secret', flush: true);

      final configService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await configService.init();

      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(baseDirProvider: () async => baseDir),
        qiniuClient: QiniuClient(),
        cacheBaseDirProvider: () async => baseDir,
      );

      final cached = await service.getCachedFile(key: '../secret.txt');
      expect(outside.existsSync(), isTrue);
      expect(cached, isNull);
    });

    test('ensureCachedFile：七牛公有空间应下载并落盘缓存，二次调用不重复下载', () async {
      final baseDir = await Directory.systemTemp.createTemp('life_tools_test_');
      addTearDown(() async {
        try {
          await baseDir.delete(recursive: true);
        } catch (_) {}
      });

      final configService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await configService.init();
      await configService.save(
        const ObjStoreConfig.qiniu(
          bucket: 'bkt',
          domain: 'https://cdn.example.com',
          uploadHost: 'https://upload.qiniup.com',
          keyPrefix: '',
          isPrivate: false,
        ),
        secrets: const ObjStoreQiniuSecrets(accessKey: 'ak', secretKey: 'sk'),
      );

      final client = _CountingHttpClient(body: Uint8List.fromList([9, 8, 7]));
      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(baseDirProvider: () async => baseDir),
        qiniuClient: QiniuClient(
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
        cacheBaseDirProvider: () async => baseDir,
        cacheHttpClient: client,
      );

      const key = 'media/abc.png';
      final f1 = await service.ensureCachedFile(key: key);
      expect(f1, isNotNull);
      expect(f1!.existsSync(), isTrue);
      expect(await f1.readAsBytes(), [9, 8, 7]);
      expect(client.getCount, 1);

      final f2 = await service.ensureCachedFile(key: key);
      expect(f2!.path, f1.path);
      expect(client.getCount, 1);
    });

    test(
      'ensureCachedFile：key 为带 query 的 URL 时应复用同一缓存（避免 token 变化导致重复下载）',
      () async {
        final baseDir = await Directory.systemTemp.createTemp(
          'life_tools_test_',
        );
        addTearDown(() async {
          try {
            await baseDir.delete(recursive: true);
          } catch (_) {}
        });

        final configService = ObjStoreConfigService(
          secretStore: InMemorySecretStore(),
        );
        await configService.init();

        final client = _CountingHttpClient(body: Uint8List.fromList([1, 1, 2]));
        final service = ObjStoreService(
          configService: configService,
          localStore: LocalObjStore(baseDirProvider: () async => baseDir),
          qiniuClient: QiniuClient(),
          cacheBaseDirProvider: () async => baseDir,
          cacheHttpClient: client,
        );

        const url1 = 'https://cdn.example.com/media/a.png?e=1&token=t1';
        const url2 = 'https://cdn.example.com/media/a.png?e=2&token=t2';

        final f1 = await service.ensureCachedFile(
          key: url1,
          resolveUriWhenMiss: () async => url1,
        );
        expect(f1, isNotNull);
        expect(client.getCount, 1);

        final f2 = await service.ensureCachedFile(
          key: url2,
          resolveUriWhenMiss: () async => url2,
        );
        expect(f2, isNotNull);
        expect(f2!.path, f1!.path);
        expect(client.getCount, 1);
      },
    );
  });
}
