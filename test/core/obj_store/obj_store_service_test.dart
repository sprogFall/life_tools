import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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

class _RecordingHttpClient extends http.BaseClient {
  _RecordingHttpClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  http.BaseRequest? lastRequest;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastRequest = request;
    return _handler(request);
  }
}

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

      final client = _RecordingHttpClient((request) async {
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
  });
}
