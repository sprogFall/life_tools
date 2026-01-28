import 'package:flutter_test/flutter_test.dart';
import 'package:life_tools/core/obj_store/obj_store_config.dart';
import 'package:life_tools/core/obj_store/obj_store_config_service.dart';
import 'package:life_tools/core/obj_store/obj_store_secrets.dart';
import 'package:life_tools/core/obj_store/secret_store/in_memory_secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ObjStoreConfigService', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('默认应为未选择', () async {
      final service = ObjStoreConfigService(secretStore: InMemorySecretStore());
      await service.init();

      expect(service.config, isNull);
      expect(service.isConfigured, isFalse);
      expect(service.selectedType, ObjStoreType.none);
    });

    test('保存本地存储后应为已配置', () async {
      final service = ObjStoreConfigService(secretStore: InMemorySecretStore());
      await service.init();

      await service.save(const ObjStoreConfig.local());

      expect(service.selectedType, ObjStoreType.local);
      expect(service.isConfigured, isTrue);
    });

    test('保存七牛配置（含AK/SK）后应为已配置，并可在重启后恢复', () async {
      final secretStore = InMemorySecretStore();
      final service = ObjStoreConfigService(secretStore: secretStore);
      await service.init();

      await service.save(
        const ObjStoreConfig.qiniu(
          bucket: 'bkt',
          domain: 'https://example.com',
          uploadHost: 'https://upload.qiniup.com',
          keyPrefix: 'media/',
        ),
        secrets: const ObjStoreQiniuSecrets(accessKey: 'ak', secretKey: 'sk'),
      );

      expect(service.selectedType, ObjStoreType.qiniu);
      expect(service.isConfigured, isTrue);

      final service2 = ObjStoreConfigService(secretStore: secretStore);
      await service2.init();

      expect(service2.selectedType, ObjStoreType.qiniu);
      expect(service2.isConfigured, isTrue);
      expect(service2.qiniuSecrets, isNotNull);
      expect(service2.qiniuSecrets!.accessKey, 'ak');
    });

    test('数据胶囊：保存配置（含AK/SK）后应为已配置，并可在重启后恢复', () async {
      final secretStore = InMemorySecretStore();
      final service = ObjStoreConfigService(secretStore: secretStore);
      await service.init();

      await service.save(
        const ObjStoreConfig.dataCapsule(
          bucket: 'bkt',
          endpoint: 'https://s3.example.com',
          region: 'test-region',
          keyPrefix: 'media/',
          isPrivate: false,
          useHttps: false,
          forcePathStyle: false,
        ),
        dataCapsuleSecrets: const ObjStoreDataCapsuleSecrets(
          accessKey: 'ak',
          secretKey: 'sk',
        ),
      );

      expect(service.selectedType, ObjStoreType.dataCapsule);
      expect(service.isConfigured, isTrue);
      expect(
        service.config!.dataCapsuleRegion,
        ObjStoreConfig.dataCapsuleFixedRegion,
      );
      expect(
        service.config!.dataCapsuleUseHttps,
        ObjStoreConfig.dataCapsuleFixedUseHttps,
      );
      expect(
        service.config!.dataCapsuleIsPrivate,
        ObjStoreConfig.dataCapsuleFixedIsPrivate,
      );
      expect(
        service.config!.dataCapsuleForcePathStyle,
        ObjStoreConfig.dataCapsuleFixedForcePathStyle,
      );

      final service2 = ObjStoreConfigService(secretStore: secretStore);
      await service2.init();

      expect(service2.selectedType, ObjStoreType.dataCapsule);
      expect(service2.isConfigured, isTrue);
      expect(service2.dataCapsuleSecrets, isNotNull);
      expect(service2.dataCapsuleSecrets!.accessKey, 'ak');
      expect(
        service2.config!.dataCapsuleRegion,
        ObjStoreConfig.dataCapsuleFixedRegion,
      );
      expect(
        service2.config!.dataCapsuleUseHttps,
        ObjStoreConfig.dataCapsuleFixedUseHttps,
      );
      expect(
        service2.config!.dataCapsuleIsPrivate,
        ObjStoreConfig.dataCapsuleFixedIsPrivate,
      );
      expect(
        service2.config!.dataCapsuleForcePathStyle,
        ObjStoreConfig.dataCapsuleFixedForcePathStyle,
      );
    });

    test('清除后应恢复为未选择', () async {
      final service = ObjStoreConfigService(secretStore: InMemorySecretStore());
      await service.init();

      await service.save(const ObjStoreConfig.local());
      expect(service.isConfigured, isTrue);

      await service.clear();
      expect(service.config, isNull);
      expect(service.isConfigured, isFalse);
      expect(service.selectedType, ObjStoreType.none);
    });
  });
}
