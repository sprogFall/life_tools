import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/obj_store/data_capsule/data_capsule_client.dart';
import 'package:life_tools/core/obj_store/obj_store_config.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/obj_store_errors.dart';
import 'package:life_tools/core/obj_store/obj_store_service.dart';
import 'package:life_tools/core/obj_store/obj_store_secrets.dart';
import 'package:life_tools/core/obj_store/qiniu/qiniu_auth.dart';
import 'package:life_tools/core/obj_store/qiniu/qiniu_client.dart';
import 'package:life_tools/core/obj_store/secret_store/in_memory_secret_store.dart';
import 'package:life_tools/core/obj_store/storage/local_obj_store.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_helpers/recording_http_client.dart';

void main() {
  group('ObjStoreService', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('未配置时调用应抛出未配置异常', () async {
      final configService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await configService.init();

      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(
          baseDirProvider: () async => Directory.systemTemp.createTemp(),
        ),
        qiniuClient: QiniuClient(
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
      );

      await expectLater(
        () => service.uploadBytes(
          bytes: Uint8List.fromList([1, 2, 3]),
          filename: 'a.bin',
        ),
        throwsA(isA<ObjStoreNotConfiguredException>()),
      );
    });

    test('本地存储：上传后应生成可查询的本地路径', () async {
      final configService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await configService.init();
      await configService.save(const ObjStoreConfig.local());

      final tempDir = await Directory.systemTemp.createTemp();
      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(baseDirProvider: () async => tempDir),
        qiniuClient: QiniuClient(
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
      );

      final result = await service.uploadBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'a.bin',
      );

      expect(result.storageType, ObjStoreType.local);
      expect(result.key, isNotEmpty);
      expect(result.uri, startsWith('file://'));

      final resolved = await service.resolveUri(key: result.key);
      expect(resolved, result.uri);

      final filePath = Uri.parse(result.uri).toFilePath();
      expect(File(filePath).existsSync(), isTrue);
    });

    test('七牛存储：上传后应返回可访问URL（domain+key）', () async {
      final secretStore = InMemorySecretStore();
      final configService = ObjStoreConfigService(secretStore: secretStore);
      await configService.init();
      await configService.save(
        const ObjStoreConfig.qiniu(
          bucket: 'bkt',
          domain: 'https://cdn.example.com',
          uploadHost: 'https://upload.qiniup.com',
          keyPrefix: 'media/',
        ),
        secrets: const ObjStoreQiniuSecrets(accessKey: 'ak', secretKey: 'sk'),
      );

      final client = RecordingHttpClient((request) async {
        final bodyBytes = await request.finalize().fold<List<int>>(
          <int>[],
          (acc, chunk) => acc..addAll(chunk),
        );
        final bodyText = utf8.decode(bodyBytes);
        expect(request.url.toString(), 'https://upload.qiniup.com/');
        expect(bodyText.contains('token'), isTrue);
        expect(bodyText.contains('media/'), isTrue);
        final resp = jsonEncode({'key': 'media/abc.png', 'hash': 'x'});
        return http.StreamedResponse(Stream.value(utf8.encode(resp)), 200);
      });

      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(
          baseDirProvider: () async => Directory.systemTemp.createTemp(),
        ),
        qiniuClient: QiniuClient(
          httpClient: client,
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
      );

      final result = await service.uploadBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'abc.png',
      );

      expect(result.storageType, ObjStoreType.qiniu);
      expect(result.key, 'media/abc.png');
      expect(result.uri, 'https://cdn.example.com/media/abc.png');
    });

    test('七牛存储：http 协议时应返回 http 链接', () async {
      final secretStore = InMemorySecretStore();
      final configService = ObjStoreConfigService(secretStore: secretStore);
      await configService.init();
      await configService.save(
        const ObjStoreConfig.qiniu(
          bucket: 'bkt',
          domain: 'cdn.example.com',
          uploadHost: 'https://upload.qiniup.com',
          keyPrefix: 'media/',
          useHttps: false,
        ),
        secrets: const ObjStoreQiniuSecrets(accessKey: 'ak', secretKey: 'sk'),
      );

      final client = RecordingHttpClient((request) async {
        final resp = jsonEncode({'key': 'media/abc.png', 'hash': 'x'});
        return http.StreamedResponse(Stream.value(utf8.encode(resp)), 200);
      });

      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(
          baseDirProvider: () async => Directory.systemTemp.createTemp(),
        ),
        qiniuClient: QiniuClient(
          httpClient: client,
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
      );

      final result = await service.uploadBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'abc.png',
      );

      expect(result.key, 'media/abc.png');
      expect(result.uri, 'http://cdn.example.com/media/abc.png');
    });

    test('七牛私有空间：上传后应返回带签名的临时URL', () async {
      final secretStore = InMemorySecretStore();
      final configService = ObjStoreConfigService(secretStore: secretStore);
      await configService.init();
      await configService.save(
        const ObjStoreConfig.qiniu(
          bucket: 'bkt',
          domain: 'https://cdn.example.com',
          uploadHost: 'https://upload.qiniup.com',
          keyPrefix: 'media/',
          isPrivate: true,
        ),
        secrets: const ObjStoreQiniuSecrets(
          accessKey: 'testak',
          secretKey: 'testsk',
        ),
      );

      final client = RecordingHttpClient((request) async {
        final resp = jsonEncode({'key': 'media/abc.png', 'hash': 'x'});
        return http.StreamedResponse(Stream.value(utf8.encode(resp)), 200);
      });

      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(
          baseDirProvider: () async => Directory.systemTemp.createTemp(),
        ),
        qiniuClient: QiniuClient(
          httpClient: client,
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
        qiniuPrivateDeadlineUnixSeconds: () => 1234567890,
      );

      final result = await service.uploadBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'abc.png',
      );

      expect(result.key, 'media/abc.png');
      expect(
        result.uri,
        'https://cdn.example.com/media/abc.png?e=1234567890&token=testak:FMNTFUnuG-wbXiPViZ0RjV026sE=',
      );
    });

    test('七牛私有空间：查询时应返回带签名的临时URL', () async {
      final secretStore = InMemorySecretStore();
      final configService = ObjStoreConfigService(secretStore: secretStore);
      await configService.init();

      final cfg = const ObjStoreConfig.qiniu(
        bucket: 'bkt',
        domain: 'https://cdn.example.com',
        uploadHost: 'https://upload.qiniup.com',
        keyPrefix: 'media/',
        isPrivate: true,
      );
      final secrets = const ObjStoreQiniuSecrets(
        accessKey: 'testak',
        secretKey: 'testsk',
      );

      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(
          baseDirProvider: () async => Directory.systemTemp.createTemp(),
        ),
        qiniuClient: QiniuClient(
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
        qiniuPrivateDeadlineUnixSeconds: () => 1234567890,
      );

      final uri = await service.resolveUriWithConfig(
        config: cfg,
        key: 'media/abc.png',
        secrets: secrets,
      );

      expect(
        uri,
        'https://cdn.example.com/media/abc.png?e=1234567890&token=testak:FMNTFUnuG-wbXiPViZ0RjV026sE=',
      );
    });

    test('七牛私有空间：当 key 已是 URL 时，应提取 objectKey 并重新签名', () async {
      final configService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await configService.init();

      final cfg = const ObjStoreConfig.qiniu(
        bucket: 'bkt',
        domain: 'https://cdn.example.com',
        uploadHost: 'https://upload.qiniup.com',
        keyPrefix: '',
        isPrivate: true,
      );
      final secrets = const ObjStoreQiniuSecrets(
        accessKey: 'testak',
        secretKey: 'testsk',
      );

      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(
          baseDirProvider: () async => Directory.systemTemp.createTemp(),
        ),
        qiniuClient: QiniuClient(
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
        qiniuPrivateDeadlineUnixSeconds: () => 1234567890,
      );

      final uri = await service.resolveUriWithConfig(
        config: cfg,
        key: 'https://cdn.example.com/media/abc.png',
        secrets: secrets,
      );

      expect(
        uri,
        'https://cdn.example.com/media/abc.png?e=1234567890&token=testak:FMNTFUnuG-wbXiPViZ0RjV026sE=',
      );
    });

    test('本地存储：当 key 已是 file:// URL 时，应直接返回（用于兼容历史导入）', () async {
      final configService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await configService.init();

      final tmp = await Directory.systemTemp.createTemp();
      addTearDown(() async {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {}
      });

      final localStore = LocalObjStore(baseDirProvider: () async => tmp);
      final stored = await localStore.saveBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'a.png',
      );

      final service = ObjStoreService(
        configService: configService,
        localStore: localStore,
        qiniuClient: QiniuClient(
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
      );

      final uri = await service.resolveUriWithConfig(
        config: const ObjStoreConfig.local(),
        key: stored.uri,
      );
      expect(uri, stored.uri);
    });

    test('数据胶囊存储：上传后应使用PUT并返回可用URL（含签名）', () async {
      final secretStore = InMemorySecretStore();
      final configService = ObjStoreConfigService(secretStore: secretStore);
      await configService.init();
      await configService.save(
        const ObjStoreConfig.dataCapsule(
          bucket: 'bkt',
          endpoint: 'https://s3.example.com',
          region: 'test-region',
          keyPrefix: 'media/',
          isPrivate: true,
          useHttps: true,
          forcePathStyle: true,
        ),
        dataCapsuleSecrets: const ObjStoreDataCapsuleSecrets(
          accessKey: 'ak',
          secretKey: 'sk',
        ),
      );

      final client = RecordingHttpClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.toString(), contains('/bkt/media/'));

        final auth =
            request.headers['Authorization'] ??
            request.headers['authorization'];
        expect(auth, isNotNull);
        expect(auth!, contains('Credential=ak/'));
        expect(auth, contains('/test-region/s3/aws4_request'));

        final bodyBytes = await request.finalize().fold<List<int>>(
          <int>[],
          (acc, chunk) => acc..addAll(chunk),
        );
        expect(bodyBytes, [1, 2, 3]);

        return http.StreamedResponse(Stream.value(const <int>[]), 200);
      });

      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(
          baseDirProvider: () async => Directory.systemTemp.createTemp(),
        ),
        qiniuClient: QiniuClient(
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
        dataCapsuleClient: DataCapsuleClient(
          httpClient: client,
          nowUtc: () => DateTime.utc(2020, 1, 1, 0, 0, 0),
        ),
      );

      final result = await service.uploadBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'abc.png',
      );

      expect(result.storageType, ObjStoreType.dataCapsule);
      expect(result.key, startsWith('media/'));
      expect(result.uri, isNotEmpty);

      final uri = Uri.parse(result.uri);
      expect(uri.queryParameters['X-Amz-Algorithm'], 'AWS4-HMAC-SHA256');
      expect(
        uri.queryParameters['X-Amz-Credential'],
        contains('ak/20200101/test-region/s3/aws4_request'),
      );
      expect(uri.queryParameters['X-Amz-SignedHeaders'], 'host');
      expect(uri.queryParameters['X-Amz-Signature'], isNotEmpty);
    });

    test('数据胶囊私有空间：当 key 已是 URL 时应重新签名', () async {
      final configService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await configService.init();

      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(
          baseDirProvider: () async => Directory.systemTemp.createTemp(),
        ),
        qiniuClient: QiniuClient(
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
        dataCapsuleClient: DataCapsuleClient(
          nowUtc: () => DateTime.utc(2020, 1, 1, 0, 0, 0),
        ),
      );

      const cfg = ObjStoreConfig.dataCapsule(
        bucket: 'bkt',
        endpoint: 'https://s3.example.com',
        region: 'test-region',
        keyPrefix: '',
        isPrivate: true,
        useHttps: true,
        forcePathStyle: true,
      );

      final uriText = await service.resolveUriWithConfig(
        config: cfg,
        key: 'https://s3.example.com/bkt/media/a.png?old=1',
        dataCapsuleSecrets: const ObjStoreDataCapsuleSecrets(
          accessKey: 'ak',
          secretKey: 'sk',
        ),
      );

      final uri = Uri.parse(uriText);
      expect(uri.path, '/bkt/media/a.png');
      expect(uri.queryParameters.containsKey('old'), isFalse);
      expect(uri.queryParameters['X-Amz-Algorithm'], 'AWS4-HMAC-SHA256');
      expect(uri.queryParameters['X-Amz-Signature'], isNotEmpty);
    });

    test('数据胶囊：Region 缺省时应使用 us-east-1 参与签名', () async {
      final client = RecordingHttpClient((request) async {
        final auth =
            request.headers['Authorization'] ??
            request.headers['authorization'];
        expect(auth, isNotNull);
        expect(auth!, contains('/us-east-1/s3/aws4_request'));
        return http.StreamedResponse(Stream.value(const <int>[]), 200);
      });

      final configService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await configService.init();

      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(
          baseDirProvider: () async => Directory.systemTemp.createTemp(),
        ),
        qiniuClient: QiniuClient(
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
        dataCapsuleClient: DataCapsuleClient(
          httpClient: client,
          nowUtc: () => DateTime.utc(2020, 1, 1, 0, 0, 0),
        ),
      );

      await service.uploadBytesWithConfig(
        config: const ObjStoreConfig.dataCapsule(
          bucket: 'bkt',
          endpoint: 'https://s3.example.com',
          region: '',
          keyPrefix: 'media/',
          isPrivate: true,
          useHttps: true,
          forcePathStyle: true,
        ),
        dataCapsuleSecrets: const ObjStoreDataCapsuleSecrets(
          accessKey: 'ak',
          secretKey: 'sk',
        ),
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'a.bin',
      );
    });

    test('数据胶囊：probeWithConfig 应使用 GET（避免 HEAD 导致预签名校验失败）', () async {
      final client = RecordingHttpClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['Range'], 'bytes=0-0');
        return http.StreamedResponse(Stream.value(const <int>[]), 206);
      });

      final configService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await configService.init();

      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(
          baseDirProvider: () async => Directory.systemTemp.createTemp(),
        ),
        qiniuClient: QiniuClient(
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
        dataCapsuleClient: DataCapsuleClient(
          httpClient: client,
          nowUtc: () => DateTime.utc(2020, 1, 1, 0, 0, 0),
        ),
      );

      final ok = await service.probeWithConfig(
        config: const ObjStoreConfig.dataCapsule(
          bucket: 'bkt',
          endpoint: 'https://s3.example.com',
          region: 'us-east-1',
          keyPrefix: '',
          isPrivate: false,
          useHttps: true,
          forcePathStyle: true,
        ),
        key: 'media/a.png',
      );
      expect(ok, isTrue);
    });

    test('数据胶囊私有空间：probeWithConfig 应走签名 GET', () async {
      final client = RecordingHttpClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['Range'], 'bytes=0-0');
        expect(
          request.headers['Authorization'] ?? request.headers['authorization'],
          isNotNull,
        );
        expect(request.headers['x-amz-date'], isNotNull);
        expect(request.headers['x-amz-content-sha256'], isNotNull);
        return http.StreamedResponse(Stream.value(const <int>[]), 206);
      });

      final configService = ObjStoreConfigService(
        secretStore: InMemorySecretStore(),
      );
      await configService.init();

      final service = ObjStoreService(
        configService: configService,
        localStore: LocalObjStore(
          baseDirProvider: () async => Directory.systemTemp.createTemp(),
        ),
        qiniuClient: QiniuClient(
          authFactory: (ak, sk) => QiniuAuth(accessKey: ak, secretKey: sk),
        ),
        dataCapsuleClient: DataCapsuleClient(
          httpClient: client,
          nowUtc: () => DateTime.utc(2020, 1, 1, 0, 0, 0),
        ),
      );

      final ok = await service.probeWithConfig(
        config: const ObjStoreConfig.dataCapsule(
          bucket: 'bkt',
          endpoint: 'https://s3.cstcloud.cn',
          region: 'us-east-1',
          keyPrefix: '',
          isPrivate: true,
          useHttps: true,
          forcePathStyle: true,
        ),
        key: 'media/a.png',
        dataCapsuleSecrets: const ObjStoreDataCapsuleSecrets(
          accessKey: 'ak',
          secretKey: 'sk',
        ),
      );
      expect(ok, isTrue);
    });
  });
}
